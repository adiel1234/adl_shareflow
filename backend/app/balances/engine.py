"""
Balance Engine — ADL ShareFlow

Algorithm:
1. Calculate net balance for every user in the group:
   net[user] = total_paid - total_owed
2. Apply confirmed settlements (reduces outstanding balances)
3. Include former members who appear in expenses but are no longer active GroupMembers
4. Separate into creditors (net > 0) and debtors (net < 0)
5. Greedy two-pointer matching to minimize number of transactions

This produces the minimum number of settlements needed to clear all debts.
"""
from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Dict

from app.models import Expense, ExpenseParticipant, GroupMember, Settlement


@dataclass
class UserBalance:
    user_id: str
    display_name: str
    net_amount: Decimal       # positive = owed money, negative = owes money
    total_paid: Decimal
    total_owed: Decimal
    is_former_member: bool = False


@dataclass
class SettlementSuggestion:
    from_user_id: str
    from_display_name: str
    to_user_id: str
    to_display_name: str
    amount: Decimal
    currency: str
    from_is_former_member: bool = False
    to_is_former_member: bool = False


def calculate_group_balances(group_id: str) -> List[UserBalance]:
    """Returns net balance per user in base currency (converted_amount).

    Includes former members who appear in expenses but are no longer active
    GroupMembers. Confirmed settlements are factored into net balances.
    """
    from app.models import User
    from app import db

    members = GroupMember.query.filter_by(group_id=group_id).all()
    user_map: Dict[str, GroupMember] = {m.user_id: m for m in members}
    active_user_ids = set(user_map.keys())

    paid: Dict[str, Decimal] = {uid: Decimal('0') for uid in user_map}
    owed: Dict[str, Decimal] = {uid: Decimal('0') for uid in user_map}

    def _ensure(uid: str) -> None:
        if uid not in paid:
            paid[uid] = Decimal('0')
        if uid not in owed:
            owed[uid] = Decimal('0')

    expenses = Expense.query.filter_by(group_id=group_id).all()
    for expense in expenses:
        _ensure(expense.paid_by)
        paid[expense.paid_by] += Decimal(str(expense.converted_amount))

        for participant in expense.participants:
            _ensure(participant.user_id)
            owed[participant.user_id] += Decimal(str(participant.share_amount))

    # Subtract confirmed settlements from net balances:
    # - from_user paid their debt → net[from] increases (add to paid)
    # - to_user received payment  → net[to]   decreases (add to owed)
    confirmed = Settlement.query.filter_by(
        group_id=group_id, status='confirmed'
    ).all()
    for s in confirmed:
        amount = Decimal(str(s.amount))
        _ensure(s.from_user_id)
        _ensure(s.to_user_id)
        paid[s.from_user_id] += amount
        owed[s.to_user_id] += amount

    all_user_ids = set(paid.keys()) | set(owed.keys())

    balances = []
    for uid in all_user_ids:
        p = paid.get(uid, Decimal('0'))
        o = owed.get(uid, Decimal('0'))
        net = p - o
        is_former = uid not in active_user_ids

        if uid in user_map:
            member = user_map[uid]
            display_name = member.user.display_name if member.user else uid
        else:
            user = db.session.get(User, uid)
            display_name = user.display_name if user else uid

        balances.append(UserBalance(
            user_id=uid,
            display_name=display_name,
            net_amount=net.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP),
            total_paid=p.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP),
            total_owed=o.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP),
            is_former_member=is_former,
        ))

    return sorted(balances, key=lambda b: b.net_amount, reverse=True)


def calculate_settlement_plan(group_id: str, base_currency: str = 'ILS') -> List[SettlementSuggestion]:
    """
    Returns the minimum set of transfers to settle all debts.

    Pending settlements (awaiting creditor confirmation) are treated as
    in-flight payments so open debts don't duplicate in the UI.
    """
    balances = calculate_group_balances(group_id)

    former_ids = {b.user_id for b in balances if b.is_former_member}

    # Adjust nets for pending settlements (same logic as confirmed, but not yet final)
    net_by_user: Dict[str, Decimal] = {b.user_id: b.net_amount for b in balances}
    pending = Settlement.query.filter_by(group_id=group_id, status='pending').all()
    for s in pending:
        amount = Decimal(str(s.amount))
        net_by_user[s.from_user_id] = net_by_user.get(s.from_user_id, Decimal('0')) + amount
        net_by_user[s.to_user_id] = net_by_user.get(s.to_user_id, Decimal('0')) - amount

    name_by_user = {b.user_id: b.display_name for b in balances}

    creditors = []
    debtors = []

    for uid, net in net_by_user.items():
        display_name = name_by_user.get(uid)
        if not display_name:
            from app.models import User
            from app import db
            user = db.session.get(User, uid)
            display_name = user.display_name if user else uid
        if net > Decimal('0.01'):
            creditors.append({'user_id': uid, 'name': display_name, 'amount': net})
        elif net < Decimal('-0.01'):
            debtors.append({'user_id': uid, 'name': display_name, 'amount': abs(net)})

    creditors.sort(key=lambda x: x['amount'], reverse=True)
    debtors.sort(key=lambda x: x['amount'], reverse=True)

    suggestions: List[SettlementSuggestion] = []

    i, j = 0, 0
    while i < len(debtors) and j < len(creditors):
        debtor = debtors[i]
        creditor = creditors[j]

        transfer = min(debtor['amount'], creditor['amount'])
        transfer = transfer.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

        if transfer > Decimal('0.01'):
            suggestions.append(SettlementSuggestion(
                from_user_id=debtor['user_id'],
                from_display_name=debtor['name'],
                to_user_id=creditor['user_id'],
                to_display_name=creditor['name'],
                amount=transfer,
                currency=base_currency,
                from_is_former_member=debtor['user_id'] in former_ids,
                to_is_former_member=creditor['user_id'] in former_ids,
            ))

        debtor['amount'] -= transfer
        creditor['amount'] -= transfer

        if debtor['amount'] <= Decimal('0.01'):
            i += 1
        if creditor['amount'] <= Decimal('0.01'):
            j += 1

    return suggestions


def check_group_books_balanced(group_id: str) -> tuple[bool, str | None]:
    """
    Returns (True, None) when expenses and settlement plan are consistent.
    False when participant shares don't sum to expense amounts, or when
    there are creditors but no debtors (unmatched surplus from bad shares).
    """
    expenses = Expense.query.filter_by(group_id=group_id).all()
    for expense in expenses:
        share_sum = sum(
            Decimal(str(p.share_amount)) for p in expense.participants
        )
        expected = Decimal(str(expense.converted_amount))
        if abs(share_sum - expected) > Decimal('0.01'):
            return False, 'share_mismatch'

    balances = calculate_group_balances(group_id)
    creditors = [b for b in balances if b.net_amount > Decimal('0.01')]
    debtors = [b for b in balances if b.net_amount < Decimal('-0.01')]

    if creditors and not debtors:
        return False, 'unmatched_surplus'
    if debtors and not creditors:
        return False, 'unmatched_deficit'
    return True, None
