import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../data/notifications_repository.dart';
import '../../domain/notification_model.dart';

/// Shows a dialog with the full notification title and body.
/// For settlement requests, optional approve / navigate actions are shown.
Future<void> showNotificationDetailDialog(
  BuildContext context, {
  required String title,
  required String body,
  String? type,
  String? groupId,
  String? settlementId,
  Future<bool> Function()? onConfirmSettlement,
  VoidCallback? onGoToGroup,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx)!;
      final displayTitle = _localizedTitle(l, type) ?? title;
      final isSettlementRequest = type == 'settlement_requested';
      final canConfirm = isSettlementRequest &&
          settlementId != null &&
          settlementId.isNotEmpty &&
          onConfirmSettlement != null;
      final canGoToGroup = isSettlementRequest &&
          groupId != null &&
          groupId.isNotEmpty &&
          onGoToGroup != null;

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
          if (canGoToGroup)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onGoToGroup();
              },
              child: Text(l.goToConfirmPayment),
            ),
          if (canConfirm)
            ElevatedButton.icon(
              onPressed: () async {
                await onConfirmSettlement();
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.check, size: 18),
              label: Text(l.confirmReceipt),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      );
    },
  );
}

/// Opens the detail dialog for an in-app notification list item.
Future<void> showAppNotificationDialog(
  BuildContext context,
  AppNotification notification, {
  Future<bool> Function(String settlementId)? onConfirmSettlement,
  void Function(String groupId)? onGoToGroup,
}) {
  final settlementId = notification.data['settlement_id'] as String?;
  final groupId = notification.data['group_id'] as String?;
  return showNotificationDetailDialog(
    context,
    title: notification.title,
    body: resolveNotificationDisplayBody(notification),
    type: notification.type,
    groupId: groupId,
    settlementId: settlementId,
    onConfirmSettlement:
        settlementId != null && onConfirmSettlement != null
            ? () => onConfirmSettlement(settlementId)
            : null,
    onGoToGroup: groupId != null && onGoToGroup != null
        ? () => onGoToGroup(groupId)
        : null,
  );
}

/// Resolves full body when user taps a push (app closed/background).
/// Fetches in-app notification from API so event_summary includes transfers.
Future<String> resolveNotificationBodyForPushTap({
  required String type,
  required String body,
  String? groupId,
}) async {
  if (type != 'event_summary' ||
      groupId == null ||
      groupId.isEmpty) {
    return body;
  }
  try {
    final result = await NotificationsRepository().getNotifications(page: 1);
    for (final n in result.items) {
      if (n.type == 'event_summary' &&
          (n.data['group_id'] as String?) == groupId) {
        return resolveNotificationDisplayBody(n);
      }
    }
  } catch (_) {
    // Fall back to push body.
  }
  return body;
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
    lines.add('הכל מאוזן, אין חובות');
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
