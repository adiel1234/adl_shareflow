import 'package:flutter/material.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';

/// Shown once after the button spotlight tour (or alone if tour already done).
const kHomeHowToDoneKey = 'home_howto_done_v1';

Future<bool> isHomeHowToDone() async {
  return await AppSecureStorage.read(kHomeHowToDoneKey) == 'true';
}

Future<void> markHomeHowToDone() async {
  await AppSecureStorage.write(kHomeHowToDoneKey, 'true');
}

/// One-page overview of how to use the app — short and scannable.
Future<void> showHomeHowTo(
  BuildContext context, {
  bool markDone = true,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !markDone,
    builder: (ctx) => const _HomeHowToDialog(),
  );
  if (markDone) await markHomeHowToDone();
}

class _HomeHowToDialog extends StatelessWidget {
  const _HomeHowToDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final steps = <(IconData, String)>[
      (Icons.group_add_outlined, l.howToStep1),
      (Icons.person_add_alt_1_outlined, l.howToStep2),
      (Icons.receipt_long_outlined, l.howToStep3),
      (Icons.account_balance_wallet_outlined, l.howToStep4),
      (Icons.notifications_outlined, l.howToStep5),
    ];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.howToTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.howToSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...steps.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(s.$1, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          s.$2,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l.howToGotIt,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
