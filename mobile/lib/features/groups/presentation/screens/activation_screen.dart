import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/group_model.dart';
import '../../../../l10n/app_localizations.dart';

/// Shown when a group hits the free limit and needs activation.
/// For event groups in expired state, shows extend option.
/// For ongoing groups in read_only state, shows renew option.
class ActivationScreen extends ConsumerStatefulWidget {
  final Group group;
  const ActivationScreen({super.key, required this.group});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  bool _splitAmongGroup = true;
  bool _loading = false;

  bool get _isExtend => widget.group.groupState == 'expired';
  bool get _isRenew => widget.group.groupState == 'read_only';
  bool get _isUpgrade => widget.group.tierUpgradeRequired;

  /// Compute price locally — mirrors backend MonetizationConfig exactly.
  int get _price {
    if (_isUpgrade) return widget.group.upgradePriceDiff ?? 0;
    if (_isExtend) return 15;
    final count = widget.group.memberCount;
    if (widget.group.groupType == 'ongoing') {
      if (count <= 5) return 49;
      if (count <= 8) return 69;
      if (count <= 11) return 79;
      return 89;
    } else {
      // event (default)
      if (count <= 5) return 15;
      if (count <= 10) return 20;
      if (count <= 15) return 30;
      if (count <= 39) return 35;
      return 45;
    }
  }

  String _title(AppLocalizations l) {
    if (_isUpgrade) return l.upgradeTierTitle;
    if (_isExtend) return l.extendGroupTitle;
    if (_isRenew) return l.renewGroupTitle;
    return l.activateGroupTitle;
  }

  String _durationLabel(AppLocalizations l) {
    if (_isUpgrade) return '';
    if (_isExtend) return l.sevenDaysPlus;
    return widget.group.groupType == 'ongoing' ? l.thirtyDays : l.sevenDays;
  }

  String _buttonLabel(AppLocalizations l) {
    if (_isUpgrade) return l.upgradeBtnLabel(_price);
    if (_isExtend) return l.extendBtnLabel(_price);
    if (_isRenew) return l.renewBtnLabel(_price);
    return l.activateBtnLabel(_price);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(groupRepositoryProvider);
      if (_isUpgrade) {
        await repo.upgradeTier(widget.group.id,
            splitAmongGroup: _splitAmongGroup);
      } else if (_isExtend) {
        await repo.extendGroup(widget.group.id,
            splitAmongGroup: _splitAmongGroup);
      } else if (_isRenew) {
        await repo.renewGroup(widget.group.id,
            splitAmongGroup: _splitAmongGroup);
      } else {
        await repo.activateGroup(widget.group.id,
            splitAmongGroup: _splitAmongGroup);
      }
      ref.invalidate(groupsProvider);
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isUpgrade
              ? l.upgradedSuccess
              : _isExtend
                  ? l.extendedSuccess
                  : _isRenew
                      ? l.renewedSuccess
                      : l.activatedSuccess)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorTryAgain)),
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
        title: Text(_title(l)),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // State card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    _isUpgrade ? '⬆️' : _isExtend ? '⏰' : _isRenew ? '🔄' : '⚡',
                    style: const TextStyle(fontSize: 44),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _title(l),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.group.name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Price breakdown
            _PriceRow(label: l.paymentAmountLabel, value: '$_price ₪'),
            if (_durationLabel(l).isNotEmpty)
              _PriceRow(label: l.validityLabel, value: _durationLabel(l)),
            _PriceRow(
              label: l.participantsLabel,
              value: l.memberCount(widget.group.memberCount),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Split option
            Text(
              l.howToRecordPayment,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _SplitOption(
              label: l.splitAmongAll,
              subtitle: l.splitAmongAllDesc,
              selected: _splitAmongGroup,
              onTap: () => setState(() => _splitAmongGroup = true),
            ),
            const SizedBox(height: 8),
            _SplitOption(
              label: l.payAlone,
              subtitle: l.payAloneDesc,
              selected: !_splitAmongGroup,
              onTap: () => setState(() => _splitAmongGroup = false),
            ),

            const SizedBox(height: 32),

            // Note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isUpgrade ? l.upgradeTierDesc : l.betaNoteActivation,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_buttonLabel(l),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _SplitOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SplitOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.07)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.textDisabled,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        )),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
