"""
InternalExpenseService — creates system-generated expenses for platform payments.

When a group is activated, extended, or renewed, the payment amount is injected
as a group expense so it is visible in balances. The payer can choose to:
  - split it equally among all group members (split_among_group=True)
  - bear it alone (split_among_group=False)
"""
from datetime import date
from decimal import Decimal, ROUND_HALF_UP

from app import db
from app.models import Expense, ExpenseParticipant, GroupMember


_SOURCE_LABELS = {
    'activation': 'ADL ShareFlow Service',
    'extension': 'ADL ShareFlow Service',
    'renewal': 'ADL ShareFlow Service',
    'upgrade': 'ADL ShareFlow Service',
}


def create_payment_expense(
    group,
    payer_id: str,
    amount: Decimal,
    source: str,        # 'activation' | 'extension' | 'renewal'
    split_among_group: bool,
) -> Expense:
    """
    Create and persist a system expense for a platform payment.
    Returns the created Expense (not yet committed — caller commits).
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
        notes=f'ADL ShareFlow — {source}',
        created_by=payer_id,
        is_system_expense=True,
        expense_source=source,
    )
    db.session.add(expense)
    db.session.flush()  # get expense.id

    # Determine participants
    if split_among_group:
        member_ids = [
            m.user_id for m in
            GroupMember.query.filter_by(group_id=group.id).all()
        ]
    else:
        member_ids = [payer_id]

    n = len(member_ids)
    if n == 0:
        member_ids = [payer_id]
        n = 1

    base_share = (amount / n).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    last_share = amount - base_share * (n - 1)

    for i, uid in enumerate(member_ids):
        share = base_share if i < n - 1 else last_share
        db.session.add(ExpenseParticipant(
            expense_id=expense.id,
            user_id=uid,
            share_amount=share,
        ))

    return expense
