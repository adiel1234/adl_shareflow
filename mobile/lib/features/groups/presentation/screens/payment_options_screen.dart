import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';

/// Shown when a group member wants to settle a debt.
/// Always shows Bit, PayBox, and bank transfer options.
/// If recipient hasn't configured details, shows a prompt.
class PaymentOptionsScreen extends StatefulWidget {
  final String recipientName;
  final double amount;
  final String currency;
  final String? recipientPhone;
  final String? recipientPayboxLink;
  final String? bankName;
  final String? bankBranch;
  final String? bankAccountNumber;

  const PaymentOptionsScreen({
    super.key,
    required this.recipientName,
    required this.amount,
    required this.currency,
    this.recipientPhone,
    this.recipientPayboxLink,
    this.bankName,
    this.bankBranch,
    this.bankAccountNumber,
  });

  @override
  State<PaymentOptionsScreen> createState() => _PaymentOptionsScreenState();
}

class _PaymentOptionsScreenState extends State<PaymentOptionsScreen> {
  int get _roundedAmount => widget.amount.round();

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.cannotOpenApp)),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.errorOpeningApp)),
        );
      }
    }
  }

  /// Shows a confirmation sheet with amount + phone, then opens the app
  void _showAppLaunchConfirm(String appName, String phone, String scheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    '$_roundedAmount ${widget.currency}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'לטלפון $phone',
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _launchUrl('$scheme://');
                },
                child: Text('פתח $appName'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens Bit via confirmation sheet
  void _openBit(String phone) => _showAppLaunchConfirm('Bit', phone, 'bit');

  /// Opens PayBox via confirmation sheet.
  /// If a personal PayBox link is stored, opens it directly (Universal Link).
  /// Otherwise falls back to manual phone input then `paybox://`.
  void _openPayBox(String phone) {
    final link = widget.recipientPayboxLink;
    if (link != null && link.isNotEmpty) {
      _showPayboxLinkConfirm(link, phone);
    } else {
      _showAppLaunchConfirm('PayBox', phone, 'paybox');
    }
  }

  /// Shows amount + confirmation sheet, then opens the PayBox Universal Link.
  void _showPayboxLinkConfirm(String link, String phone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    '$_roundedAmount ${widget.currency}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (phone.isNotEmpty)
                    Text(
                      'לטלפון $phone',
                      style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _launchUrl(link);
                },
                child: const Text('פתח PayBox'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a bottom sheet to enter phone number manually, then opens [scheme]://
  void _showPhoneInput(String appName, String scheme) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 24,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'העברה דרך $appName',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                'סכום להעברה: $_roundedAmount ${widget.currency}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'הזן את מספר הטלפון של ${widget.recipientName}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '05X-XXXXXXX',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final phone = controller.text.trim();
                  if (phone.length < 9) return;
                  Navigator.pop(ctx);
                  _launchUrl('$scheme://');
                },
                child: Text('פתח $appName'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final phone = widget.recipientPhone;
    final payboxLink = widget.recipientPayboxLink;
    final hasPayboxDetails = payboxLink != null || phone != null;
    final hasBankDetails = widget.bankAccountNumber != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.sendPayment),
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
                    '$_roundedAmount ${widget.currency}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.payTo(widget.recipientName),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              l.choosePaymentMethod,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 14),

            // Bit
            _PaymentTile(
              emoji: '💙',
              title: 'Bit',
              subtitle: phone != null
                  ? phone
                  : 'המקבל לא הגדיר מספר טלפון',
              hasDetails: phone != null,
              onTap: () {
                if (phone != null) {
                  _openBit(phone);
                } else {
                  _showPhoneInput('Bit', 'bit');
                }
              },
            ),

            // PayBox
            _PaymentTile(
              emoji: '🟢',
              title: 'PayBox',
              subtitle: payboxLink != null
                  ? 'קישור אישי מוגדר'
                  : phone != null
                      ? phone
                      : 'המקבל לא הגדיר קישור PayBox',
              hasDetails: hasPayboxDetails,
              onTap: () {
                if (hasPayboxDetails) {
                  _openPayBox(phone ?? '');
                } else {
                  _showPhoneInput('PayBox', 'paybox');
                }
              },
            ),

            // Bank transfer
            hasBankDetails
                ? _BankTransferTile(
                    bankName: widget.bankName,
                    bankBranch: widget.bankBranch,
                    bankAccountNumber: widget.bankAccountNumber!,
                    amount: _roundedAmount,
                    currency: widget.currency,
                    recipientName: widget.recipientName,
                  )
                : _PaymentTile(
                    emoji: '🏦',
                    title: l.bankTransfer,
                    subtitle: 'המקבל לא הגדיר פרטי בנק',
                    hasDetails: false,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'המקבל לא הגדיר פרטי בנק בפרופיל שלו'),
                        ),
                      );
                    },
                  ),

            const SizedBox(height: 20),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ℹ️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ניתן לעדכן פרטי תשלום (Bit/PayBox/בנק) בפרופיל → "פרטי תשלום"',
                      style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 12,
                          height: 1.4),
                    ),
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
  final bool hasDetails;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.hasDetails,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasDetails
                      ? AppColors.border
                      : AppColors.border.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Text(emoji,
                      style: TextStyle(
                          fontSize: 26,
                          color: hasDetails ? null : Colors.grey)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: hasDetails
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary)),
                        Text(subtitle,
                            style: TextStyle(
                                color: hasDetails
                                    ? AppColors.textSecondary
                                    : AppColors.textDisabled,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(
                    hasDetails
                        ? Icons.open_in_new
                        : Icons.edit_outlined,
                    color: hasDetails
                        ? AppColors.textDisabled
                        : AppColors.primary,
                    size: 18,
                  ),
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
    final l = AppLocalizations.of(context)!;
    final text = [
      if (bankName != null) '${l.bankLabel}: $bankName',
      if (bankBranch != null) '${l.branchLabel}: $bankBranch',
      '${l.accountLabel}: $bankAccountNumber',
      '${l.amountLabel}: $amount $currency',
      '${l.forCredit}: $recipientName',
    ].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.bankDetailsCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
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
            Row(
              children: [
                const Text('🏦', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(l.bankTransfer,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            if (bankName != null) _BankRow(l.bankLabel, bankName!),
            if (bankBranch != null) _BankRow(l.branchLabel, bankBranch!),
            _BankRow(l.accountLabel, bankAccountNumber),
            _BankRow(l.amountLabel, '$amount $currency'),
            _BankRow(l.forCredit, recipientName),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyAll(context),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(l.copyAll),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
