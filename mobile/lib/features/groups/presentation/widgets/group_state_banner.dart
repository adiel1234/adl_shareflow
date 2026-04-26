import 'package:flutter/material.dart';
import '../../domain/group_model.dart';
import '../../../../l10n/app_localizations.dart';

/// Displays a contextual banner when the group is not in a fully operational state.
class GroupStateBanner extends StatelessWidget {
  final Group group;
  final VoidCallback? onActionTap;

  const GroupStateBanner({
    super.key,
    required this.group,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final config = _bannerConfig(group, l);
    if (config == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: config.bgColor,
      child: Row(
        children: [
          Text(config.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: config.textColor,
                  ),
                ),
                Text(
                  config.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: config.textColor.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (config.actionLabel != null && onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                foregroundColor: config.textColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: config.textColor.withOpacity(0.4)),
                ),
              ),
              child: Text(
                config.actionLabel!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerConfig {
  final String emoji;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final Color bgColor;
  final Color textColor;

  const _BannerConfig({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    required this.bgColor,
    required this.textColor,
  });
}

int _localPrice(Group group) {
  final count = group.memberCount;
  if (group.groupType == 'ongoing') {
    if (count <= 5) return 49;
    if (count <= 8) return 69;
    if (count <= 11) return 79;
    return 89;
  } else {
    if (count <= 5) return 15;
    if (count <= 10) return 20;
    if (count <= 15) return 30;
    if (count <= 39) return 35;
    return 45;
  }
}

_BannerConfig? _bannerConfig(Group group, AppLocalizations l) {
  // Tier upgrade takes priority over state banners
  if (group.tierUpgradeRequired && group.upgradePriceDiff != null) {
    return _BannerConfig(
      emoji: '⬆️',
      title: l.tierUpgradeRequired,
      subtitle: l.tierUpgradeSubtitle(group.upgradePriceDiff!),
      actionLabel: l.tierUpgradeBtn,
      bgColor: const Color(0xFFFFF3CD),
      textColor: const Color(0xFF92400E),
    );
  }

  final price = _localPrice(group);

  switch (group.groupState) {
    case 'limited':
      return _BannerConfig(
        emoji: '⚡',
        title: l.bannerLimitedTitle,
        subtitle: l.bannerLimitedSubtitle(price),
        actionLabel: l.bannerActivate,
        bgColor: const Color(0xFFFFF7ED),
        textColor: const Color(0xFFB45309),
      );
    case 'expired':
      return _BannerConfig(
        emoji: '⏰',
        title: l.bannerExpiredTitle,
        subtitle: l.bannerExpiredSubtitle,
        actionLabel: l.bannerExtend,
        bgColor: const Color(0xFFFEF2F2),
        textColor: const Color(0xFFB91C1C),
      );
    case 'read_only':
      return _BannerConfig(
        emoji: '🔒',
        title: l.bannerReadOnlyTitle,
        subtitle: l.bannerReadOnlySubtitle(price),
        actionLabel: l.bannerRenew,
        bgColor: const Color(0xFFF5F3FF),
        textColor: const Color(0xFF6D28D9),
      );
    case 'free':
      return _BannerConfig(
        emoji: '🆓',
        title: l.bannerFreeTitle,
        subtitle: l.bannerFreeSubtitle,
        bgColor: const Color(0xFFF0FDF4),
        textColor: const Color(0xFF15803D),
      );
    default:
      return null;
  }
}
