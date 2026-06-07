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
    body: notification.body,
    type: notification.type,
  );
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
