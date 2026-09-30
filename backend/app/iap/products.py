"""Authoritative ILS amount → Apple/Play consumable Product ID map.

This does not define ShareFlow pricing. Pricing stays in MonetizationConfig.
These IDs only collect an already-calculated amount.
"""

PRICE_TO_PRODUCT_ID = {
    5: 'com.adl.shareflow.tier_5',
    10: 'com.adl.shareflow.tier_10',
    15: 'com.adl.shareflow.tier_15',
    20: 'com.adl.shareflow.tier_20',
    25: 'com.adl.shareflow.tier_25',
    30: 'com.adl.shareflow.tier_30',
    35: 'com.adl.shareflow.tier_35',
    40: 'com.adl.shareflow.tier_40',
    45: 'com.adl.shareflow.tier_45',
    49: 'com.adl.shareflow.tier_49',
    69: 'com.adl.shareflow.tier_69',
    79: 'com.adl.shareflow.tier_79',
    89: 'com.adl.shareflow.tier_89',
}


def product_id_for_amount(amount_ils: int | None) -> str | None:
    if amount_ils is None:
        return None
    return PRICE_TO_PRODUCT_ID.get(int(amount_ils))


def required_amount_ils(group, operation: str) -> int | None:
    """Required ILS for a paid action, from server group state + MonetizationConfig."""
    from app.models import GroupMember
    from app.groups.lifecycle_service import MonetizationConfig, check_tier_upgrade

    count = GroupMember.query.filter_by(group_id=group.id).count()
    if operation == 'activation':
        pricing = MonetizationConfig.resolve_price(group.group_type, count)
        return int(pricing['amount']) if pricing else None
    if operation == 'upgrade':
        info = check_tier_upgrade(
            group.group_type, count, group.max_participants_snapshot
        )
        return int(info['upgrade_price_diff']) if info else None
    if operation == 'extension':
        return int(MonetizationConfig.EVENT_EXTENSION_PRICE)
    if operation == 'renewal':
        pricing = MonetizationConfig.resolve_price(group.group_type, count)
        return int(pricing['amount']) if pricing else None
    return None
