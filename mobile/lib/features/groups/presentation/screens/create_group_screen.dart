import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/app_button.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/app_localizations.dart';

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
  bool _loading = false;

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
    setState(() => _loading = true);
    try {
      await ref.read(groupRepositoryProvider).createGroup(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            baseCurrency: _currency,
            category: _category,
            groupType: _groupType,
          );
      if (mounted) Navigator.pop(context);
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
                    onTap: () => setState(() => _groupType = 'event'),
                  ),
                  const SizedBox(width: 10),
                  _TypeCard(
                    title: l.groupTypeOngoing,
                    subtitle: l.monthly,
                    icon: Icons.autorenew_rounded,
                    selected: _groupType == 'ongoing',
                    onTap: () => setState(() => _groupType = 'ongoing'),
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
                label: l.createGroupBtn,
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
