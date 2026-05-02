class Group {
  final String id;
  final String name;
  final String? description;
  final String baseCurrency;
  final String? category;
  final String? inviteCode;
  final bool isActive;
  final bool isClosed;
  final int memberCount;
  final int expenseCount;
  final String? myRole;
  final String? adminName;
  final DateTime? createdAt;
  // Lifecycle / monetization
  final String groupType;    // 'event' | 'ongoing'
  final String groupState;   // 'free' | 'limited' | 'active' | 'expired' | 'read_only'
  final String? pricingTier;
  final DateTime? activatedAt;
  final DateTime? expiryDate;
  final Map<String, dynamic>? requiredPricing;
  // Periodic settlement
  final String settlementType;   // 'none' | 'periodic'
  final String? settlementPeriod; // 'weekly'|'biweekly'|'monthly'|...
  final DateTime? nextSettlementDate;
  final DateTime? currentPeriodStart;
  // Tier upgrade
  final bool tierUpgradeRequired;
  final int? upgradePriceDiff;   // amount to pay for the upgrade
  final int? upgradeNewPrice;    // new full tier price

  const Group({
    required this.id,
    required this.name,
    this.description,
    required this.baseCurrency,
    this.category,
    this.inviteCode,
    this.isActive = true,
    this.isClosed = false,
    this.memberCount = 0,
    this.expenseCount = 0,
    this.myRole,
    this.adminName,
    this.createdAt,
    this.groupType = 'event',
    this.groupState = 'free',
    this.pricingTier,
    this.activatedAt,
    this.expiryDate,
    this.requiredPricing,
    this.settlementType = 'none',
    this.settlementPeriod,
    this.nextSettlementDate,
    this.currentPeriodStart,
    this.tierUpgradeRequired = false,
    this.upgradePriceDiff,
    this.upgradeNewPrice,
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        baseCurrency: json['base_currency'] as String? ?? 'ILS',
        category: json['category'] as String?,
        inviteCode: json['invite_code'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        isClosed: json['is_closed'] as bool? ?? false,
        memberCount: json['member_count'] as int? ?? 0,
        expenseCount: json['expense_count'] as int? ?? 0,
        myRole: json['my_role'] as String?,
        adminName: json['admin_name'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        groupType: json['group_type'] as String? ?? 'event',
        groupState: json['group_state'] as String? ?? 'free',
        pricingTier: json['pricing_tier'] as String?,
        activatedAt: json['activated_at'] != null
            ? DateTime.tryParse(json['activated_at'] as String)
            : null,
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'] as String)
            : null,
        requiredPricing: json['required_pricing'] as Map<String, dynamic>?,
        settlementType: json['settlement_type'] as String? ?? 'none',
        settlementPeriod: json['settlement_period'] as String?,
        nextSettlementDate: json['next_settlement_date'] != null
            ? DateTime.tryParse(json['next_settlement_date'] as String)
            : null,
        currentPeriodStart: json['current_period_start'] != null
            ? DateTime.tryParse(json['current_period_start'] as String)
            : null,
        tierUpgradeRequired: json['tier_upgrade_required'] as bool? ?? false,
        upgradePriceDiff: (json['upgrade_price_diff'] as num?)?.toInt(),
        upgradeNewPrice: (json['upgrade_new_price'] as num?)?.toInt(),
      );

  String get categoryEmoji {
    switch (category) {
      case 'apartment': return '🏠';
      case 'trip': return '✈️';
      case 'vehicle': return '🚗';
      case 'event': return '🎉';
      default: return '👥';
    }
  }

  bool get isAdmin => myRole == 'admin';

  /// True when add/edit/delete operations are allowed.
  bool get isOperational => groupState == 'free' || groupState == 'active';

  /// True when the group needs activation (free limit hit or awaiting payment).
  bool get needsActivation => groupState == 'limited';

  /// True when the group has expired (event) or billing lapsed (ongoing).
  bool get isExpiredOrReadOnly =>
      groupState == 'expired' || groupState == 'read_only';

  bool get isPeriodic => settlementType == 'periodic';

  String get settlementPeriodLabel {
    switch (settlementPeriod) {
      case 'weekly':     return 'שבועי';
      case 'biweekly':   return 'דו-שבועי';
      case 'monthly':    return 'חודשי';
      case 'bimonthly':  return 'דו-חודשי';
      case 'quarterly':  return 'רבעוני';
      case 'semiannual': return 'חצי-שנתי';
      case 'annual':     return 'שנתי';
      default:           return '';
    }
  }

  String get groupTypeLabel => groupType == 'ongoing' ? 'שוטף' : 'אירוע';

  String get stateLabel {
    switch (groupState) {
      case 'free': return 'חינמי';
      case 'limited': return 'דרושה הפעלה';
      case 'active': return 'פעיל';
      case 'expired': return 'פג תוקף';
      case 'read_only': return 'קריאה בלבד';
      default: return groupState;
    }
  }
}

class GroupMember {
  final String id;
  final String groupId;
  final String userId;
  final String role;
  final String? nickname;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final bool isGuest;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    this.nickname,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.isGuest = false,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return GroupMember(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      nickname: json['nickname'] as String?,
      displayName: user?['display_name'] as String?,
      email: user?['email'] as String?,
      avatarUrl: user?['avatar_url'] as String?,
      isGuest: user?['is_guest'] as bool? ?? false,
    );
  }

  String get displayLabel => nickname ?? displayName ?? email ?? userId;
  bool get isAdmin => role == 'admin';
}
