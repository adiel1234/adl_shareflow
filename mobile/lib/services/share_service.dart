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

  /// שיתוף WhatsApp ספציפי (ללא נמען — בוחרים ידנית באפליקציה).
  /// מנסה deep-link ישיר (whatsapp://) לפני web fallback (wa.me).
  /// Deep-link אמין יותר כי אינו עובר דרך דפדפן שיכול לאבד את הטקסט.
  static Future<void> shareViaWhatsApp(String text) async {
    final encoded = Uri.encodeComponent(text);

    // Deep-link ישיר — אמין יותר, נפתח ישירות ב-WhatsApp
    final waAppUrl = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(waAppUrl)) {
      await launchUrl(waAppUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // Web fallback — wa.me מפנה לאפליקציה אך יכול לעבור דפדפן
    final waWebUrl = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(waWebUrl)) {
      await launchUrl(waWebUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // Last resort — פאנל שיתוף מערכת
    await Share.share(text);
  }

  /// מנרמל מספר טלפון לפורמט בינלאומי ל-wa.me (ללא +).
  static String? normalizePhoneForWaMe(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return null;
    if (digits.startsWith('0')) {
      digits = '972${digits.substring(1)}';
    }
    return digits;
  }

  /// פותח שיחת WhatsApp לנמען ספציפי עם טקסט מוכן.
  ///
  /// מגבלה: WhatsApp לא מאפשר שליחת הודעות פרטיות בשקט מרובות משתמשי אפליקציה
  /// רגילה. ללא WhatsApp Business API, כל נמען דורש פתיחת wa.me והקשה על «שלח»
  /// בתוך WhatsApp.
  static Future<bool> openWhatsAppToPhone({
    required String phone,
    required String text,
  }) async {
    final normalized = normalizePhoneForWaMe(phone);
    if (normalized == null) return false;
    final encoded = Uri.encodeComponent(text);
    final waUrl = Uri.parse('https://wa.me/$normalized?text=$encoded');
    if (await canLaunchUrl(waUrl)) {
      return launchUrl(waUrl, mode: LaunchMode.externalApplication);
    }
    return false;
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
