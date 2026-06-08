import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/notification_model.dart';

/// Shows a dialog with the full notification title and body.
Future<void> showNotificationDetailDialog(
  BuildContext context, {
  required String title,
  required String body,
  String? type,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx)!;
      final displayTitle = _localizedTitle(l, type) ?? title;

      return AlertDialog(
        title: Text(
          displayTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.notifClose),
          ),
        ],
      );
    },
  );
}

/// Opens the detail dialog for an in-app notification list item.
Future<void> showAppNotificationDialog(
  BuildContext context,
  AppNotification notification,
) {
  return showNotificationDetailDialog(
    context,
    title: notification.title,
    body: resolveNotificationDisplayBody(notification),
    type: notification.type,
  );
}

/// Prefer full summary from [AppNotification.data] when body was stored short.
String resolveNotificationDisplayBody(AppNotification notification) {
  if (notification.type != 'event_summary') return notification.body;
  final summary = notification.data['summary'];
  if (summary is! Map) return notification.body;
  return _formatEventSummaryBody(Map<String, dynamic>.from(summary));
}

String _formatEventSummaryBody(Map<String, dynamic> summary) {
  final totals = summary['totals_by_currency'];
  String totalLine;
  if (totals is Map && totals.length == 1) {
    final entry = totals.entries.first;
    totalLine = 'סה"כ: ${entry.value} ${entry.key}';
  } else {
    totalLine = 'סה"כ: ${summary['total_summary'] ?? '0'}';
  }
  final lines = <String>[
    totalLine,
    'משתתפים: ${summary['member_count']}',
    'עלות ממוצעת: ${summary['avg_per_member']}',
  ];
  final transfers = summary['transfers'];
  if (transfers is List && transfers.isNotEmpty) {
    lines.add('');
    lines.add('העברות נדרשות:');
    for (final t in transfers) {
      if (t is! Map) continue;
      final amount = t['amount']?.toString() ?? '0';
      final amountStr =
          (double.tryParse(amount)?.round() ?? amount).toString();
      lines.add(
        '• ${t['from_name']} חייב ל-${t['to_name']} $amountStr ${t['currency']}',
      );
    }
  } else if (summary['books_balanced'] != false) {
    lines.add('');
    lines.add('הכל מאוזן — אין חובות');
  }
  return lines.join('\n');
}

String? _localizedTitle(AppLocalizations l, String? type) {
  switch (type) {
    case 'new_expense':
      return l.notifNewExpenseTitle;
    case 'settlement_requested':
      return l.notifSettlementRequestedTitle;
    case 'settlement_confirmed':
      return l.notifSettlementConfirmedTitle;
    case 'member_joined':
      return l.notifMemberJoinedTitle;
    case 'event_summary':
      return l.notifEventSummaryTitle;
    default:
      return null;
  }
}
