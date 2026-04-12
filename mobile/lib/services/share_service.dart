import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareService {
  /// שיתוף לינק הזמנה לקבוצה
  static Future<void> shareGroupInvite({
    required String groupName,
    required String inviteCode,
    required String inviteUrl,
  }) async {
    final text = '''
הצטרף לקבוצה "$groupName" ב-ADL ShareFlow!

לחץ על הלינק הבא להצטרפות:
$inviteUrl

קוד הזמנה: $inviteCode
'''.trim();

    await _share(text, subject: 'הזמנה לקבוצה $groupName');
  }

  /// שיתוף WhatsApp ספציפי
  static Future<void> shareViaWhatsApp(String text) async {
    final encoded = Uri.encodeComponent(text);
    final waUrl = Uri.parse('https://wa.me/?text=$encoded');

    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to native share
      await Share.share(text);
    }
  }

  /// שיתוף סיכום יתרות קבוצה
  static Future<void> shareBalanceSummary({
    required String groupName,
    required String summary,
  }) async {
    final text = '''
סיכום יתרות — $groupName 📊

$summary

נשלח דרך ADL ShareFlow
'''.trim();

    await _share(text, subject: 'סיכום $groupName');
  }

  /// שיתוף הוצאה ספציפית
  static Future<void> shareExpense({
    required String groupName,
    required String expenseTitle,
    required double amount,
    required String currency,
    required String paidBy,
  }) async {
    final text =
        '$paidBy שילם $amount $currency עבור "$expenseTitle" בקבוצה $groupName — ADL ShareFlow';
    await _share(text);
  }

  static Future<void> _share(String text, {String? subject}) async {
    if (kIsWeb) {
      // On web, use clipboard or WhatsApp web
      final encoded = Uri.encodeComponent(text);
      final waUrl = Uri.parse('https://wa.me/?text=$encoded');
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl);
      }
    } else {
      await Share.share(text, subject: subject);
    }
  }
}
