import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/groups_provider.dart';
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
  String _settlementType = 'none';   // 'none' | 'periodic'
  String _settlementPeriod = 'monthly';
  bool _loading = false;
  int _tierIdx = 0;   // selected pricing tier index

  // Event tiers: (maxParticipants, priceIls, durationDays)
  // maxParticipants=0 means "free"
  static const _kEventTiers = [
    (0,   0,  0),   // free
    (5,   15, 7),
    (10,  20, 7),
    (15,  30, 7),
    (39,  35, 7),
    (999, 45, 7),
  ];

  // Ongoing tiers: (maxParticipants, priceIls, durationDays=30)
  static const _kOngoingTiers = [
    (5,   49, 30),
    (8,   69, 30),
    (11,  79, 30),
    (999, 89, 30),
  ];

  List<(int, int, int)> get _tiers =>
      _groupType == 'event' ? _kEventTiers : _kOngoingTiers;

  int get _selectedPrice => _tiers[_tierIdx].$2;
  bool get _isFree => _selectedPrice == 0;

  static const _kPeriodKeys = [
    'weekly', 'biweekly', 'monthly', 'bimonthly', 'quarterly', 'semiannual', 'annual',
  ];

  String _periodLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'weekly':     return l.periodWeekly;
      case 'biweekly':   return l.periodBiweekly;
      case 'monthly':    return l.periodMonthly;
      case 'bimonthly':  return l.periodBimonthly;
      case 'quarterly':  return l.periodQuarterly;
      case 'semiannual': return l.periodSemiannual;
      case 'annual':     return l.periodAnnual;
      default:           return key;
    }
  }

  static const _kBlue   = Color(0xFF1D4ED8);
  static const _kTeal   = Color(0xFF0D9488);
  static const _kPurple = Color(0xFF7C3AED);

  static const _categoryKeys = [
    ('apartment', Icons.home_rounded,           _kTeal,   _kBlue),
    ('trip',      Icons.flight_rounded,          _kBlue,   _kTeal),
    ('vehicle',   Icons.directions_car_rounded,  _kBlue,   _kPurple),
    ('event',     Icons.celebration_rounded,     _kPurple, _kBlue),
    ('other',     Icons.group_rounded,           _kTeal,   _kPurple),
  ];

  String _catLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'apartment': return l.categoryApartment;
      case 'trip':      return l.categoryTrip;
      case 'vehicle':   return l.categoryVehicle;
      case 'event':     return l.categoryEvent;
      default:          return l.categoryOther;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
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
                category: _category,
                groupType: _groupType,
                settlementType: _settlementType,
                settlementPeriod: _settlementType == 'periodic' ? _settlementPeriod : null,
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
        Navigator.pop(context);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.newGroup),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group type selector
              Text(
                l.activityType,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _TypeCard(
                    title: l.groupTypeEvent,
                    subtitle: l.sevenDays,
                    icon: Icons.celebration_rounded,
                    selected: _groupType == 'event',
                    onTap: () => setState(() { _groupType = 'event'; _tierIdx = 0; }),
                  ),
                  const SizedBox(width: 10),
                  _TypeCard(
                    title: l.groupTypeOngoing,
                    subtitle: l.monthly,
                    icon: Icons.autorenew_rounded,
                    selected: _groupType == 'ongoing',
                    onTap: () => setState(() { _groupType = 'ongoing'; _tierIdx = 0; }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _groupType == 'event' ? l.eventTypeDesc : l.ongoingTypeDesc,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              // ── Pricing tier selector ──
              Text(
                l.pricingSection,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_tiers.length, (i) {
                  final (maxP, price, days) = _tiers[i];
                  final selected = _tierIdx == i;
                  final isFree = price == 0;
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
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
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

              // Price preview card
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _isFree
                      ? const Color(0xFFF0FDF4)
                      : AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isFree
                        ? const Color(0xFF86EFAC)
                        : AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFree ? Icons.card_giftcard_rounded : Icons.receipt_long_rounded,
                      color: _isFree
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
                            _isFree
                                ? l.freeIncluded
                                : l.estimatedCost,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _isFree
                                  ? const Color(0xFF16A34A)
                                  : AppColors.primary,
                            ),
                          ),
                          if (!_isFree) ...[
                            const SizedBox(height: 2),
                            Text(
                              () {
                                final (_, price, days) = _tiers[_tierIdx];
                                final dur = _groupType == 'ongoing'
                                    ? l.durationMonth
                                    : l.durationDays(days);
                                return '$price ₪ / $dur';
                              }(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Periodic settlement — only for ongoing groups
              if (_groupType == 'ongoing') ...[
                const SizedBox(height: 20),
                Text(
                  l.periodicSettlement,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'none',
                        groupValue: _settlementType,
                        onChanged: (v) => setState(() => _settlementType = v!),
                        title: Text(l.manualSettlement,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(l.manualSettlementDesc,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        activeColor: AppColors.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        value: 'periodic',
                        groupValue: _settlementType,
                        onChanged: (v) => setState(() => _settlementType = v!),
                        title: Text(l.automaticPeriodic,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(l.automaticPeriodicDesc,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        activeColor: AppColors.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ],
                  ),
                ),
                if (_settlementType == 'periodic') ...[
                  const SizedBox(height: 12),
                  Text(
                    l.settlementFrequency,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kPeriodKeys.map((key) {
                      final selected = _settlementPeriod == key;
                      return GestureDetector(
                        onTap: () => setState(() => _settlementPeriod = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Text(
                            _periodLabel(l, key),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // Category picker
              Text(
                l.category,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13),
              ),
              const SizedBox(height: 10),
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
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: selected ? LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                        color: selected ? null : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? c1 : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.$2,
                              size: 18,
                              color: selected ? Colors.white : AppColors.textSecondary),
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

              const SizedBox(height: 24),

              // Name
              _Label(l.groupName),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(hintText: l.groupNameHint),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l.groupNameRequired;
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description
              _Label(l.groupDescription),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: InputDecoration(hintText: l.groupDescriptionHint),
              ),

              const SizedBox(height: 16),

              // Currency
              _Label(l.defaultCurrency),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(),
                items: AppConstants.supportedCurrencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'ILS'),
              ),

              const SizedBox(height: 32),

              GradientButton(
                label: _isFree
                    ? l.createGroupFree
                    : l.createGroupPaid(_selectedPrice),
                onPressed: _loading ? null : () => _create(l),
                isLoading: _loading,
              ),
            ],
          ),
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
                ? AppColors.primary.withOpacity(0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 26,
                  color: selected ? AppColors.primary : AppColors.textSecondary),
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
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      );
}
