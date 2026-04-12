from datetime import date
from decimal import Decimal

from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import selectinload, joinedload

from app import db
from app.models import Expense, ExpenseParticipant, Group, GroupMember
from app.common.errors import success_response, error_response
from app.common.decorators import require_group_member, require_group_operational
from app.common.utils import to_decimal

expenses_bp = Blueprint('expenses', __name__)


@expenses_bp.get('/groups/<group_id>/expenses')
@jwt_required()
@require_group_member
def list_expenses(group_id, **kwargs):
    user_id = get_jwt_identity()
    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 20, type=int), 100)

    base_q = Expense.query.filter_by(group_id=group_id)
    total = base_q.count()

    # Eager-load participants (one-to-many via selectinload) and their user +
    # the payer (many-to-one via joinedload) to avoid N+1 lazy-loading issues
    # that caused my_share to appear as 0 on the first request.
    expenses = (
        base_q
        .options(
            selectinload(Expense.participants).joinedload(ExpenseParticipant.user),
            joinedload(Expense.payer),
        )
        .order_by(Expense.expense_date.desc(), Expense.created_at.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
        .all()
    )

    def _expense_dict(e):
        d = e.to_dict()
        my_p = next((p for p in e.participants if p.user_id == user_id), None)
        d['my_share'] = str(my_p.share_amount) if my_p else '0.00'
        d['is_payer'] = (e.paid_by == user_id)
        d['is_creator'] = (e.created_by == user_id)
        return d

    return success_response(data={
        'expenses': [_expense_dict(e) for e in expenses],
        'pagination': {'total': total, 'page': page, 'per_page': per_page},
    })


@expenses_bp.post('/groups/<group_id>/expenses')
@jwt_required()
@require_group_member
@require_group_operational
def create_expense(group_id, **kwargs):
    user_id = get_jwt_identity()
    data = request.get_json(silent=True) or {}

    title = (data.get('title') or '').strip()
    if not title:
        return error_response('title is required')

    try:
        original_amount = to_decimal(data.get('original_amount'))
        if original_amount <= 0:
            raise ValueError()
    except Exception:
        return error_response('original_amount must be a positive number')

    original_currency = (data.get('original_currency') or '').upper()
    if not original_currency:
        return error_response('original_currency is required')

    group = Group.query.get(group_id)
    if group and group.is_closed:
        return error_response('הקבוצה סגורה — לא ניתן להוסיף הוצאות חדשות', 403)

    exchange_rate = to_decimal(data.get('exchange_rate', '1'))
    converted_amount = (original_amount * exchange_rate).quantize(Decimal('0.01'))

    paid_by = data.get('paid_by') or user_id
    split_type = data.get('split_type', 'equal')
    if split_type not in ('equal', 'exact', 'percentage'):
        return error_response('split_type must be equal, exact, or percentage')

    try:
        expense_date = date.fromisoformat(data.get('expense_date', date.today().isoformat()))
    except Exception:
        return error_response('expense_date must be YYYY-MM-DD')

    expense = Expense(
        group_id=group_id,
        paid_by=paid_by,
        title=title,
        original_amount=original_amount,
        original_currency=original_currency,
        exchange_rate=exchange_rate,
        converted_amount=converted_amount,
        category=data.get('category'),
        split_type=split_type,
        expense_date=expense_date,
        notes=data.get('notes'),
        created_by=user_id,
    )
    db.session.add(expense)
    db.session.flush()

    # Build participants
    participants_data = data.get('participants')
    if not participants_data:
        # Default: split equally among all group members
        members = GroupMember.query.filter_by(group_id=group_id).all()
        if not members:
            return error_response('No members in group')
        share = (converted_amount / len(members)).quantize(Decimal('0.01'))
        for m in members:
            p = ExpenseParticipant(
                expense_id=expense.id,
                user_id=m.user_id,
                share_amount=share,
            )
            db.session.add(p)
    else:
        for pd in participants_data:
            p = ExpenseParticipant(
                expense_id=expense.id,
                user_id=pd['user_id'],
                share_amount=to_decimal(pd.get('share_amount', 0)),
                share_percentage=to_decimal(pd.get('share_percentage')) if pd.get('share_percentage') else None,
            )
            db.session.add(p)

    db.session.commit()

    # Notify group members
    try:
        from app.models import User
        from app.notifications.service import notify_new_expense
        actor = User.query.get(user_id)
        actor_name = actor.display_name if actor else 'מישהו'
        notify_new_expense(expense, actor_name)
    except Exception:
        pass  # Never block expense creation due to notification failure

    return success_response(data=expense.to_dict(), status_code=201)


@expenses_bp.get('/expenses/<expense_id>')
@jwt_required()
def get_expense(expense_id):
    user_id = get_jwt_identity()
    expense = Expense.query.get(expense_id)
    if not expense:
        return error_response('Expense not found', 404)

    member = GroupMember.query.filter_by(group_id=expense.group_id, user_id=user_id).first()
    if not member:
        return error_response('Access denied', 403)

    return success_response(data=expense.to_dict())


@expenses_bp.put('/expenses/<expense_id>')
@jwt_required()
def update_expense(expense_id):
    """
    Full expense edit — only the creator (or group admin) can edit.
    Changing amount/currency recalculates converted_amount and splits shares equally.
    """
    from app.groups.lifecycle_service import GroupLifecycleService

    user_id = get_jwt_identity()
    expense = Expense.query.get(expense_id)
    if not expense:
        return error_response('Expense not found', 404)

    group = Group.query.get(expense.group_id)
    if group and not GroupLifecycleService.is_operational(group):
        return error_response('הקבוצה אינה פעילה — לא ניתן לערוך הוצאות', 403,
                              errors={'group_state': group.group_state})

    member = GroupMember.query.filter_by(
        group_id=expense.group_id, user_id=user_id
    ).first()
    if not member or (member.role != 'admin' and expense.created_by != user_id):
        return error_response('Only the expense creator or group admin can edit', 403)

    data = request.get_json(silent=True) or {}

    if 'title' in data:
        title = data['title'].strip()
        if not title:
            return error_response('title cannot be empty')
        expense.title = title

    if 'notes' in data:
        expense.notes = data['notes'] or None

    if 'category' in data:
        expense.category = data['category'] or None

    if 'expense_date' in data:
        try:
            expense.expense_date = date.fromisoformat(data['expense_date'])
        except Exception:
            return error_response('expense_date must be YYYY-MM-DD')

    if 'paid_by' in data and data['paid_by']:
        paid_member = GroupMember.query.filter_by(
            group_id=expense.group_id, user_id=data['paid_by']
        ).first()
        if not paid_member:
            return error_response('paid_by user is not a group member')
        expense.paid_by = data['paid_by']

    # Recalculate amounts if original_amount or original_currency changed
    amount_changed = 'original_amount' in data or 'original_currency' in data

    if amount_changed:
        try:
            new_amount = to_decimal(
                data.get('original_amount', str(expense.original_amount))
            )
            if new_amount <= 0:
                raise ValueError()
        except Exception:
            return error_response('original_amount must be a positive number')

        new_currency = data.get('original_currency', expense.original_currency).upper()
        exchange_rate = to_decimal(data.get('exchange_rate', str(expense.exchange_rate or '1')))
        new_converted = (new_amount * exchange_rate).quantize(Decimal('0.01'))

        expense.original_amount = new_amount
        expense.original_currency = new_currency
        expense.exchange_rate = exchange_rate
        expense.converted_amount = new_converted

        # Redistribute shares equally among current participants
        participants = ExpenseParticipant.query.filter_by(expense_id=expense.id).all()
        if participants:
            n = len(participants)
            share = (new_converted / n).quantize(Decimal('0.01'))
            for i, p in enumerate(participants):
                p.share_amount = share

    db.session.commit()

    # Notify all group members about the edit
    try:
        from app.models import User
        actor = User.query.get(user_id)
        actor_name = actor.display_name if actor else 'מישהו'
        _notify_expense_edited(expense, actor_name, user_id)
    except Exception:
        pass

    return success_response(data=expense.to_dict())


def _notify_expense_edited(expense, actor_name: str, editor_user_id: str):
    """Send in-app notification to all group members that an expense was edited."""
    from app.models import Notification
    from app.notifications import fcm_service

    members = GroupMember.query.filter_by(group_id=expense.group_id).all()
    title = 'הוצאה עודכנה'
    body = f'{actor_name} ערך את ההוצאה: {expense.title}'

    for m in members:
        if m.user_id == editor_user_id:
            continue
        db.session.add(Notification(
            user_id=m.user_id,
            type='expense_edited',
            title=title,
            body=body,
            data={
                'group_id': expense.group_id,
                'expense_id': expense.id,
            },
        ))

    db.session.commit()

    recipient_ids = [m.user_id for m in members if m.user_id != editor_user_id]
    fcm_service.send_to_users(recipient_ids, title, body, {
        'type': 'expense_edited',
        'group_id': expense.group_id,
        'expense_id': expense.id,
    })


@expenses_bp.delete('/expenses/<expense_id>')
@jwt_required()
def delete_expense(expense_id):
    from app.groups.lifecycle_service import GroupLifecycleService

    user_id = get_jwt_identity()
    expense = Expense.query.get(expense_id)
    if not expense:
        return error_response('Expense not found', 404)

    group = Group.query.get(expense.group_id)
    if group and not GroupLifecycleService.is_operational(group):
        return error_response('הקבוצה אינה פעילה — לא ניתן למחוק הוצאות', 403,
                              errors={'group_state': group.group_state})

    member = GroupMember.query.filter_by(group_id=expense.group_id, user_id=user_id).first()
    if not member or (member.role != 'admin' and expense.created_by != user_id):
        return error_response('Access denied', 403)

    db.session.delete(expense)
    db.session.commit()
    return success_response(message='Expense deleted')
