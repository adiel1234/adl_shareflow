"""
InternalExpenseService - creates system-generated expenses for platform payments.

When a group is activated, extended, or renewed, the payment amount is injected
as a group expense so it is visible in balances. The payer can choose to:
  - split it equally among all group members (split_among_group=True)
  - bear it alone (split_among_group=False)

When split_among_group=True, new members who join later are automatically added
to the expense (see add_member_to_group_split_expenses).
"""
from datetime import date
from decimal import Decimal, ROUND_HALF_UP

from app import db
from app.models import Expense, ExpenseParticipant, GroupMember, GroupPayment


_SOURCE_LABELS = {
    'activation': 'ADL ShareFlow Service',
    'extension': 'ADL ShareFlow Service',
    'renewal': 'ADL ShareFlow Service',
    'upgrade': 'ADL ShareFlow Service',
}


def _rebalance_equal_participants(expense: Expense, participant_ids: list[str]) -> None:
    """Replace participants with equal shares that sum to converted_amount."""
    amount = Decimal(str(expense.converted_amount))
    n = len(participant_ids)
    if n == 0:
        return

    base_share = (amount / n).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    last_share = amount - base_share * (n - 1)

    ExpenseParticipant.query.filter_by(expense_id=expense.id).delete(
        synchronize_session=False
    )
    db.session.flush()
    db.session.expire(expense, ['participants'])

    for i, uid in enumerate(participant_ids):
        share = base_share if i < n - 1 else last_share
        db.session.add(ExpenseParticipant(
            expense_id=expense.id,
            user_id=uid,
            share_amount=share,
        ))


def create_payment_expense(
    group,
    payer_id: str,
    amount: Decimal,
    source: str,        # 'activation' | 'extension' | 'renewal' | 'upgrade'
    split_among_group: bool,
) -> Expense:
    """
    Create and persist a system expense for a platform payment.
    Returns the created Expense (not yet committed - caller commits).
    """
    title = _SOURCE_LABELS.get(source, 'תשלום מערכת')
    today = date.today()

    expense = Expense(
        group_id=group.id,
        paid_by=payer_id,
        title=title,
        original_amount=amount,
        original_currency=group.base_currency,
        exchange_rate=Decimal('1.000000'),
        converted_amount=amount,
        category='other',
        split_type='equal',
        expense_date=today,
        notes=f'ADL ShareFlow - {source}',
        created_by=payer_id,
        is_system_expense=True,
        expense_source=source,
    )
    db.session.add(expense)
    db.session.flush()  # get expense.id

    if split_among_group:
        member_ids = [
            m.user_id for m in
            GroupMember.query.filter_by(group_id=group.id)
            .order_by(GroupMember.joined_at.asc())
            .all()
        ]
    else:
        member_ids = [payer_id]

    if not member_ids:
        member_ids = [payer_id]

    _rebalance_equal_participants(expense, member_ids)
    db.session.flush()
    return expense


def retroactively_add_member_to_expenses(group_id: str, user_id: str) -> None:
    """
    Add user_id as an equal participant on every existing group expense
    (split_mode='full' when joining or adding a guest).
    """
    expenses = Expense.query.filter_by(group_id=group_id).all()
    for expense in expenses:
        participant_ids = {p.user_id for p in expense.participants}
        if user_id in participant_ids:
            continue
        participant_ids.add(user_id)
        _rebalance_equal_participants(expense, sorted(participant_ids))
        db.session.flush()


def add_member_to_group_split_expenses(group_id: str, user_id: str) -> None:
    """
    When a new member joins, add them to system expenses that were marked
    split_among_group at payment time (activation / extension / renewal / upgrade).
    """
    payments = GroupPayment.query.filter_by(
        group_id=group_id,
        split_among_group=True,
    ).filter(GroupPayment.expense_id.isnot(None)).all()

    for payment in payments:
        expense = db.session.get(Expense, payment.expense_id)
        if not expense or not expense.is_system_expense:
            continue

        participant_ids = {p.user_id for p in expense.participants}
        if user_id in participant_ids:
            continue

        participant_ids.add(user_id)
        _rebalance_equal_participants(expense, sorted(participant_ids))
        db.session.flush()
