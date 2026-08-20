import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/payments_config_provider.dart';
import '../../../../providers/quota_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/app_button.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/app_localizations.dart';
import 'activation_screen.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _currency = 'ILS';
  String? _category;
  String _groupType = 'event';
  String _settlementType = 'none'; // 'none' | 'periodic'
  String _settlementPeriod = 'monthly';
  bool _loading = false;
  int _tierIdx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(publicAppConfigProvider);
    });
  }

  static const _kEventTiers = [
    (0, 0, 0),
    (5, 15, 7),
    (10, 20, 7),
    (15, 30, 7),
    (39, 35, 7),
    (999, 45, 7),
  ];

  static const _kOngoingTiers = [
    (5, 49, 30),
    (8, 69, 30),
    (11, 79, 30),
    (999, 89, 30),
  ];

  List<(int, int, int)> get _tiers =>
      _groupType == 'event' ? _kEventTiers : _kOngoingTiers;

  static const _kPeriodKeys = [
    'weekly',
    'biweekly',
    'monthly',
    'bimonthly',
    'quarterly',
    'semiannual',
    'annual',
  ];

  String _periodLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'weekly':
        return l.periodWeekly;
      case 'biweekly':
        return l.periodBiweekly;
      case 'monthly':
        return l.periodMonthly;
      case 'bimonthly':
        return l.periodBimonthly;
      case 'quarterly':
        return l.periodQuarterly;
      case 'semiannual':
        return l.periodSemiannual;
      case 'annual':
        return l.periodAnnual;
      default:
        return key;
    }
  }

  static const _kBlue = Color(0xFF1D4ED8);
  static const _kTeal = Color(0xFF0D9488);
  static const _kPurple = Color(0xFF7C3AED);

  static const _kEventCategoryKeys = [
    ('wedding', Icons.favorite_rounded, _kPurple, _kBlue),
    ('party', Icons.celebration_rounded, _kPurple, _kTeal),
    ('birthday', Icons.cake_rounded, _kBlue, _kPurple),
    ('other', Icons.more_horiz_rounded, _kTeal, _kPurple),
  ];

  static const _kOngoingCategoryKeys = [
    ('apartment', Icons.home_rounded, _kTeal, _kBlue),
    ('vehicle', Icons.directions_car_rounded, _kBlue, _kPurple),
    ('trip', Icons.flight_rounded, _kBlue, _kTeal),
    ('other', Icons.more_horiz_rounded, _kTeal, _kPurple),
  ];

  List<(String, IconData, Color, Color)> get _categoryKeys =>
      _groupType == 'event' ? _kEventCategoryKeys : _kOngoingCategoryKeys;

  final _customCategoryCtrl = TextEditingController();

  String? get _resolvedCategory {
    if (_category == null) return null;
    if (_category == 'other') {
      final custom = _customCategoryCtrl.text.trim();
      return custom.isEmpty ? 'other' : custom;
    }
    return _category;
  }

  String _catLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'wedding':
        return l.categoryWedding;
      case 'party':
        return l.categoryParty;
      case 'birthday':
        return l.categoryBirthday;
      case 'apartment':
        return l.categoryApartment;
      case 'trip':
        return l.categoryTrip;
      case 'vehicle':
        return l.categoryVehicle;
      default:
        return l.categoryOther;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _create(AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final (group, limitReached) =
          await ref.read(groupRepositoryProvider).createGroup(
                name: _nameCtrl.text.trim(),
                description: _descCtrl.text.trim().isEmpty
                    ? null
                    : _descCtrl.text.trim(),
                baseCurrency: _currency,
                category: _resolvedCategory,
                groupType: _groupType,
                settlementType: _settlementType,
                settlementPeriod:
                    _settlementType == 'periodic' ? _settlementPeriod : null,
              );
      if (!mounted) return;
      if (limitReached) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(l.freeGroupLimitReachedTitle),
            content: Text(l.freeGroupLimitReachedBody),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(l.laterBtn),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivationScreen(group: group),
                    ),
                  );
                },
                child: Text(l.activateGroupBtn),
              ),
            ],
          ),
        );
      } else {
        ref.invalidate(groupsProvider);
        if (!mounted) return;
        await Navigator.of(context).pushReplacementNamed(
          '/group-detail',
          arguments: {
            'groupId': group.id,
            'openInvite': true,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorCreatingGroup)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final quotaAsync = ref.watch(groupQuotaProvider);
    final limitReached = quotaAsync.maybeWhen(
      data: (q) => q.limitReached,
      orElse: () => false,
    );

    final effectiveTierIdx =
        (limitReached && _groupType == 'event' && _tierIdx == 0) ? 1 : _tierIdx;
    final (_, effectivePrice, effectiveDays) = _tiers[effectiveTierIdx];
    final isFreeEffective = effectivePrice == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.newGroup),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldSection(
                title: l.activityType,
                required: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _TypeCard(
                          title: l.groupTypeEvent,
                          subtitle: l.sevenDays,
                          icon: Icons.celebration_rounded,
                          selected: _groupType == 'event',
                          onTap: () => setState(() {
                            _groupType = 'event';
                            _tierIdx = 0;
                            _category = null;
                            _customCategoryCtrl.clear();
                          }),
                        ),
                        const SizedBox(width: 10),
                        _TypeCard(
                          title: l.groupTypeOngoing,
                          subtitle: l.monthly,
                          icon: Icons.autorenew_rounded,
                          selected: _groupType == 'ongoing',
                          onTap: () => setState(() {
                            _groupType = 'ongoing';
                            _tierIdx = 0;
                            _category = null;
                            _customCategoryCtrl.clear();
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _groupType == 'event'
                          ? l.eventTypeDesc
                          : l.ongoingTypeDesc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              _FieldSection(
                title: l.groupName,
                required: true,
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: l.groupNameHint,
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l.groupNameRequired;
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 4),
              _FieldSection(
                title: l.pricingSection,
                required: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_tiers.length, (i) {
                        final (maxP, price, days) = _tiers[i];
                        final selected = effectiveTierIdx == i;
                        final isFree = price == 0;
                        if (isFree && limitReached) {
                          return const SizedBox.shrink();
                        }
                        final label = isFree
                            ? l.freeTierLabel
                            : maxP == 999
                                ? l.aboveParticipants(
                                    _groupType == 'event' ? 40 : 12)
                                : l.upToParticipants(maxP);
                        return GestureDetector(
                          onTap: () => setState(() => _tierIdx = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                if (!isFree)
                                  Text(
                                    '$price ₪',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: selected
                                          ? Colors.white70
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isFreeEffective
                            ? const Color(0xFFF0FDF4)
                            : AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFreeEffective
                              ? const Color(0xFF86EFAC)
                              : AppColors.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isFreeEffective
                                ? Icons.card_giftcard_rounded
                                : Icons.receipt_long_rounded,
                            color: isFreeEffective
                                ? const Color(0xFF16A34A)
                                : AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFreeEffective
                                      ? l.freeIncluded
                                      : l.estimatedCost,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isFreeEffective
                                        ? const Color(0xFF16A34A)
                                        : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFreeEffective
                                      ? l.freeTierDetails
                                      : () {
                                          final dur = _groupType == 'ongoing'
                                              ? l.durationMonth
                                              : l.durationDays(effectiveDays);
                                          return '$effectivePrice ₪ / $dur';
                                        }(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: isFreeEffective
                                        ? const Color(0xFF15803D)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    l.createGroupMoreOptions,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  children: [
              if (_groupType == 'ongoing') ...[
                _FieldSection(
                  title: l.periodicSettlement,
                  required: true,
                  child: Column(
                    children: [
                      _SettlementOption(
                        selected: _settlementType == 'none',
                        title: l.manualSettlement,
                        subtitle: l.manualSettlementDesc,
                        onTap: () => setState(() => _settlementType = 'none'),
                      ),
                      const SizedBox(height: 8),
                      _SettlementOption(
                        selected: _settlementType == 'periodic',
                        title: l.automaticPeriodic,
                        subtitle: l.automaticPeriodicDesc,
                        onTap: () =>
                            setState(() => _settlementType = 'periodic'),
                      ),
                    ],
                  ),
                ),
                if (_settlementType == 'periodic')
                  _FieldSection(
                    title: l.settlementFrequency,
                    required: true,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kPeriodKeys.map((key) {
                        final selected = _settlementPeriod == key;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _settlementPeriod = key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              _periodLabel(l, key),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],

              _FieldSection(
                title: l.category,
                required: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categoryKeys.map((cat) {
                        final selected = _category == cat.$1;
                        final c1 = cat.$3;
                        final c2 = cat.$4;
                        return InkWell(
                          onTap: () => setState(() => _category = cat.$1),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? LinearGradient(
                                      colors: [c1, c2],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: selected ? null : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? c1 : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.$2,
                                  size: 18,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _catLabel(l, cat.$1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_category == 'other') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customCategoryCtrl,
                        decoration: InputDecoration(
                          hintText: l.categoryOtherHint,
                          prefixIcon: const Icon(Icons.edit_outlined),
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ],
                ),
              ),

              _FieldSection(
                title: l.groupDescription,
                required: false,
                child: TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: l.groupDescriptionHint,
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                ),
              ),

              _FieldSection(
                title: l.defaultCurrency,
                required: true,
                child: DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  items: AppConstants.supportedCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v ?? 'ILS'),
                ),
              ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final pilotMode =
                      ref.watch(pilotModeConfigProvider).maybeWhen(
                            data: (v) => v,
                            orElse: () => true,
                          );
                  final tip = !isFreeEffective
                      ? (pilotMode
                          ? l.tipCreateGroupNoCharge
                          : l.tipCreateGroupLive)
                      : null;
                  return Column(
                    children: [
                      if (tip != null) ...[
                        Text(
                          tip,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      GradientButton(
                        label: l.createGroupSubmit,
                        onPressed: _loading ? null : () => _create(l),
                        isLoading: _loading,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldSection extends StatelessWidget {
  final String title;
  final bool required;
  final Widget child;

  const _FieldSection({
    required this.title,
    required this.required,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: required
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  required ? l.fieldRequiredBadge : l.fieldOptionalBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: required
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SettlementOption extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettlementOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 26,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
