import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/group_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

// 3 professional icon colors
const _kBlue   = Color(0xFF1D4ED8);
const _kTeal   = Color(0xFF0D9488);
const _kPurple = Color(0xFF7C3AED);

IconData _categoryIcon(String? category) {
  switch (category) {
    case 'trip':      return Icons.flight_rounded;
    case 'apartment': return Icons.home_rounded;
    case 'vehicle':   return Icons.directions_car_rounded;
    case 'event':     return Icons.celebration_rounded;
    default:          return Icons.group_rounded;
  }
}

Color _gradientPrimaryColor(String? category) {
  switch (category) {
    case 'trip':      return _kBlue;
    case 'vehicle':   return _kBlue;
    case 'apartment': return _kTeal;
    case 'event':     return _kPurple;
    default:          return _kTeal;
  }
}

LinearGradient _categoryGradient(String? category) {
  switch (category) {
    case 'trip':
      return const LinearGradient(colors: [_kBlue, _kTeal], begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'vehicle':
      return const LinearGradient(colors: [_kBlue, _kPurple], begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'apartment':
      return const LinearGradient(colors: [_kTeal, _kBlue], begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'event':
      return const LinearGradient(colors: [_kPurple, _kBlue], begin: Alignment.topLeft, end: Alignment.bottomRight);
    default:
      return const LinearGradient(colors: [_kTeal, _kPurple], begin: Alignment.topLeft, end: Alignment.bottomRight);
  }
}

class GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;

  const GroupCard({super.key, required this.group, required this.onTap});

  bool get _isInactive => group.isExpiredOrReadOnly || group.isClosed;

  @override
  Widget build(BuildContext context) {
    final gradient = _isInactive ? null : _categoryGradient(group.category);
    // Primary color from gradient (first color) for borders and badges
    final primaryColor = _isInactive ? AppColors.textDisabled : _gradientPrimaryColor(group.category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Opacity(
        opacity: _isInactive ? 0.55 : 1.0,
        child: Material(
          color: _isInactive ? AppColors.surfaceVariant : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          elevation: 0,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isInactive
                      ? AppColors.border
                      : primaryColor.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Icon avatar — iOS style gradient bg + white icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      color: _isInactive ? const Color(0xFFCBD5E1) : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isInactive
                          ? Icons.lock_outline_rounded
                          : _categoryIcon(group.category),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _isInactive
                                ? AppColors.textDisabled
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                size: 13, color: AppColors.textDisabled),
                            const SizedBox(width: 3),
                            Text(
                              AppLocalizations.of(context)!.memberCount(group.memberCount),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            if (group.adminName != null) ...[
                              const SizedBox(width: 8),
                              const Text('·',
                                  style: TextStyle(
                                      color: AppColors.textDisabled,
                                      fontSize: 12)),
                              const SizedBox(width: 8),
                              const Icon(Icons.shield_outlined,
                                  size: 12, color: AppColors.textDisabled),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  group.adminName!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _StateBadge(group: group, color: primaryColor),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                group.baseCurrency,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.chevron_left_rounded,
                    color: _isInactive
                        ? AppColors.textDisabled
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final Group group;
  final Color color;
  const _StateBadge({required this.group, required this.color});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    Color bg;
    Color fg;
    String label;

    if (group.isClosed) {
      bg = AppColors.textDisabled.withOpacity(0.15);
      fg = AppColors.textDisabled;
      label = l.stateClosed;
    } else {
      switch (group.groupState) {
        case 'active':
          bg = _kTeal.withOpacity(0.12);
          fg = _kTeal;
          label = l.stateActive;
          break;
        case 'limited':
          bg = const Color(0xFFFEF3C7);
          fg = const Color(0xFFD97706);
          label = l.stateNeedsActivation;
          break;
        case 'expired':
          bg = AppColors.textDisabled.withOpacity(0.12);
          fg = AppColors.textDisabled;
          label = l.stateExpired;
          break;
        case 'read_only':
          bg = AppColors.textDisabled.withOpacity(0.12);
          fg = AppColors.textDisabled;
          label = l.stateReadOnly;
          break;
        default:
          bg = _kTeal.withOpacity(0.10);
          fg = _kTeal;
          label = l.stateFree;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
