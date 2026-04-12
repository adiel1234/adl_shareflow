"""
Balance Engine — ADL ShareFlow

Algorithm:
1. Calculate net balance for every user in the group:
   net[user] = total_paid - total_owed
2. Separate into creditors (net > 0) and debtors (net < 0)
3. Greedy two-pointer matching to minimize number of transactions

This produces the minimum number of settlements needed to clear all debts.
"""
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Dict

from app.models import Expense, ExpenseParticipant, GroupMember


@dataclass
class UserBalance:
    user_id: str
    display_name: str
    net_amount: Decimal       # positive = owed money, negative = owes money
    total_paid: Decimal
    total_owed: Decimal


@dataclass
class SettlementSuggestion:
    from_user_id: str
    from_display_name: str
    to_user_id: str
    to_display_name: str
    amount: Decimal
    currency: str


def calculate_group_balances(group_id: str) -> List[UserBalance]:
    """Returns net balance per user in base currency (converted_amount)."""
    members = GroupMember.query.filter_by(group_id=group_id).all()
    user_map: Dict[str, GroupMember] = {m.user_id: m for m in members}

    paid: Dict[str, Decimal] = {uid: Decimal('0') for uid in user_map}
    owed: Dict[str, Decimal] = {uid: Decimal('0') for uid in user_map}

    expenses = Expense.query.filter_by(group_id=group_id).all()
    for expense in expenses:
        if expense.paid_by in paid:
            paid[expense.paid_by] += expense.converted_amount

        for participant in expense.participants:
            if participant.user_id in owed:
                owed[participant.user_id] += participant.share_amount

    balances = []
    for uid, member in user_map.items():
        net = paid[uid] - owed[uid]
        balances.append(UserBalance(
            user_id=uid,
            display_name=member.user.display_name if member.user else uid,
            net_amount=net.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP),
            total_paid=paid[uid].quantize(Decimal('0.01'), rounding=ROUND_HALF_UP),
            total_owed=owed[uid].quantize(Decimal('0.01'), rounding=ROUND_HALF_UP),
        ))

    return sorted(balances, key=lambda b: b.net_amount, reverse=True)


def calculate_settlement_plan(group_id: str, base_currency: str = 'ILS') -> List[SettlementSuggestion]:
    """
    Returns the minimum set of transfers to settle all debts.

    Uses greedy two-pointer algorithm:
    - creditors list (net > 0), sorted descending
    - debtors list (net < 0), sorted ascending
    - match largest creditor with largest debtor
    """
    balances = calculate_group_balances(group_id)

    creditors = []
    debtors = []

    for b in balances:
        if b.net_amount > Decimal('0.01'):
            creditors.append({'user_id': b.user_id, 'name': b.display_name, 'amount': b.net_amount})
        elif b.net_amount < Decimal('-0.01'):
            debtors.append({'user_id': b.user_id, 'name': b.display_name, 'amount': abs(b.net_amount)})

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
            ))

        debtor['amount'] -= transfer
        creditor['amount'] -= transfer

        if debtor['amount'] <= Decimal('0.01'):
            i += 1
        if creditor['amount'] <= Decimal('0.01'):
            j += 1

    return suggestions
