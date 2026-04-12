import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../theme/app_colors.dart';

/// Shown when a group member wants to settle a debt.
/// Provides deep-link options to Bit, PayBox, and bank transfer.
class PaymentOptionsScreen extends StatelessWidget {
  final String recipientName;
  final double amount;
  final String currency;
  /// Optional: phone number for Bit/PayBox (from recipient's profile).
  final String? recipientPhone;
  /// Optional: bank details for bank transfer.
  final String? bankName;
  final String? bankBranch;
  final String? bankAccountNumber;

  const PaymentOptionsScreen({
    super.key,
    required this.recipientName,
    required this.amount,
    required this.currency,
    this.recipientPhone,
    this.bankName,
    this.bankBranch,
    this.bankAccountNumber,
  });

  int get _roundedAmount => amount.round();

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('לא ניתן לפתוח את האפליקציה')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בפתיחת האפליקציה')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('שלח תשלום'),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    '$_roundedAmount $currency',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'לתשלום ל$recipientName',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'בחר אמצעי תשלום',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 14),

            // Bit
            if (recipientPhone != null)
              _PaymentTile(
                emoji: '💙',
                title: 'Bit',
                subtitle: recipientPhone!,
                onTap: () => _launchUrl(
                  context,
                  'https://bit.ly/shareflow-bit?amount=$_roundedAmount&phone=$recipientPhone',
                ),
              ),

            // PayBox
            if (recipientPhone != null)
              _PaymentTile(
                emoji: '🟢',
                title: 'PayBox',
                subtitle: recipientPhone!,
                onTap: () => _launchUrl(
                  context,
                  'payboxapp://payment?amount=$_roundedAmount&phone=$recipientPhone',
                ),
              ),

            // Bank transfer
            if (bankAccountNumber != null)
              _BankTransferTile(
                bankName: bankName,
                bankBranch: bankBranch,
                bankAccountNumber: bankAccountNumber!,
                amount: _roundedAmount,
                currency: currency,
                recipientName: recipientName,
              ),

            if (recipientPhone == null && bankAccountNumber == null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.payment_outlined,
                        size: 36, color: AppColors.textDisabled),
                    SizedBox(height: 10),
                    Text(
                      'המקבל עדיין לא הגדיר פרטי תשלום.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'בקש ממנו להוסיף מספר טלפון לBit/PayBox או פרטי בנק בפרופיל שלו.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(subtitle,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new,
                      color: AppColors.textDisabled, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BankTransferTile extends StatelessWidget {
  final String? bankName;
  final String? bankBranch;
  final String bankAccountNumber;
  final int amount;
  final String currency;
  final String recipientName;

  const _BankTransferTile({
    this.bankName,
    this.bankBranch,
    required this.bankAccountNumber,
    required this.amount,
    required this.currency,
    required this.recipientName,
  });

  void _copyAll(BuildContext context) {
    final text = [
      if (bankName != null) 'בנק: $bankName',
      if (bankBranch != null) 'סניף: $bankBranch',
      'חשבון: $bankAccountNumber',
      'סכום: $amount $currency',
      'לזכות: $recipientName',
    ].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('פרטי הבנק הועתקו')),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('🏦', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Text('העברה בנקאית',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              if (bankName != null) _BankRow('בנק', bankName!),
              if (bankBranch != null) _BankRow('סניף', bankBranch!),
              _BankRow('חשבון', bankAccountNumber),
              _BankRow('סכום', '$amount $currency'),
              _BankRow('לזכות', recipientName),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _copyAll(context),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('העתק הכל'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _BankRow extends StatelessWidget {
  final String label;
  final String value;
  const _BankRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
}
