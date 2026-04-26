import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';

class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() =>
      _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _phoneCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    setState(() => _loading = true);
    try {
      final response = await ApiClient.instance.get('/users/me');
      final data = response.data['data'] as Map<String, dynamic>;
      _phoneCtrl.text = data['payment_phone'] ?? '';
      _bankNameCtrl.text = data['bank_name'] ?? '';
      _branchCtrl.text = data['bank_branch'] ?? '';
      _accountCtrl.text = data['bank_account_number'] ?? '';
    } catch (_) {
      // ignore, fields remain empty
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.put('/users/me', data: {
        'payment_phone': _phoneCtrl.text.trim(),
        'bank_name': _bankNameCtrl.text.trim(),
        'bank_branch': _branchCtrl.text.trim(),
        'bank_account_number': _accountCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.paymentDetailsSaved)),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.paymentDetailsSaveError)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.paymentDetails),
        backgroundColor: AppColors.background,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                      icon: '💙',
                      title: 'Bit / PayBox',
                      subtitle: l.bitPayboxSubtitle),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      hintText: '05X-XXXXXXX',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),

                  const SizedBox(height: 28),

                  _SectionHeader(
                      icon: '🏦',
                      title: l.bankTransfer,
                      subtitle: l.bankTransferSubtitle),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _bankNameCtrl,
                    decoration: InputDecoration(
                      hintText: l.bankNameHint,
                      prefixIcon: const Icon(Icons.account_balance_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _branchCtrl,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            hintText: l.bankBranchHint,
                            prefixIcon: const Icon(Icons.numbers_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _accountCtrl,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            hintText: l.bankAccountHint,
                            prefixIcon: const Icon(Icons.credit_card_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.paymentPrivacyNote,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(l.saveDetails,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  const _SectionHeader(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      );
}
