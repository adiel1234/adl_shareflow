import 'package:flutter/material.dart';
import '../../domain/group_model.dart';

/// Displays a contextual banner when the group is not in a fully operational state.
/// Shown at the top of GroupDetailScreen.
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
    final config = _bannerConfig(group);
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

/// Compute price locally — mirrors backend MonetizationConfig.
int _localPrice(Group group) {
  final count = group.memberCount;
  if (group.groupType == 'ongoing') {
    if (count <= 5) return 49;
    if (count <= 8) return 69;
    return 89;
  } else {
    if (count <= 10) return 15;
    if (count <= 15) return 20;
    return 30;
  }
}

_BannerConfig? _bannerConfig(Group group) {
  final price = _localPrice(group);

  switch (group.groupState) {
    case 'limited':
      return _BannerConfig(
        emoji: '⚡',
        title: 'נדרשת הפעלה',
        subtitle: 'הקבוצה הגיעה למגבלת החינם. עלות הפעלה: $price ₪',
        actionLabel: 'הפעל',
        bgColor: const Color(0xFFFFF7ED),
        textColor: const Color(0xFFB45309),
      );
    case 'expired':
      return _BannerConfig(
        emoji: '⏰',
        title: 'פג תוקף הקבוצה',
        subtitle: 'לא ניתן להוסיף הוצאות. הארכה: 15 ₪ ל-7 ימים נוספים.',
        actionLabel: 'הארך',
        bgColor: const Color(0xFFFEF2F2),
        textColor: const Color(0xFFB91C1C),
      );
    case 'read_only':
      return _BannerConfig(
        emoji: '🔒',
        title: 'קריאה בלבד',
        subtitle: 'פרק הזמן שבתשלום הסתיים. חידוש: $price ₪',
        actionLabel: 'חדש',
        bgColor: const Color(0xFFF5F3FF),
        textColor: const Color(0xFF6D28D9),
      );
    case 'free':
      return _BannerConfig(
        emoji: '🆓',
        title: 'מצב חינמי',
        subtitle: 'עד 3 משתתפים ו-5 ימים ללא עלות.',
        bgColor: const Color(0xFFF0FDF4),
        textColor: const Color(0xFF15803D),
      );
    default:
      return null; // 'active' — no banner needed
  }
}
