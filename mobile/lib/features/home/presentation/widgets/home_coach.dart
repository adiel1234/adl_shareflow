import 'package:flutter/material.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';

const kHomeCoachDoneKey = 'home_coach_done_v1';

class CoachTarget {
  final GlobalKey key;
  final String title;
  final String body;

  const CoachTarget({
    required this.key,
    required this.title,
    required this.body,
  });
}

Future<bool> isHomeCoachDone() async {
  return await AppSecureStorage.read(kHomeCoachDoneKey) == 'true';
}

Future<void> markHomeCoachDone() async {
  await AppSecureStorage.write(kHomeCoachDoneKey, 'true');
}

/// First-run spotlight tour over the main buttons.
Future<void> showHomeCoach(
  BuildContext context, {
  required List<CoachTarget> targets,
}) async {
  final usable = targets
      .where((t) => t.key.currentContext?.findRenderObject() != null)
      .toList();
  if (usable.isEmpty) {
    await markHomeCoachDone();
    return;
  }

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'coach',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) => _HomeCoachDialog(targets: usable),
  );
  await markHomeCoachDone();
}

class _HomeCoachDialog extends StatefulWidget {
  final List<CoachTarget> targets;
  const _HomeCoachDialog({required this.targets});

  @override
  State<_HomeCoachDialog> createState() => _HomeCoachDialogState();
}

class _HomeCoachDialogState extends State<_HomeCoachDialog> {
  int _step = 0;

  Rect? _targetRect() {
    final ctx = widget.targets[_step].key.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final offset = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      offset.dx - 8,
      offset.dy - 8,
      box.size.width + 16,
      box.size.height + 16,
    ).inflate(4);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final target = widget.targets[_step];
    final rect = _targetRect();
    final size = MediaQuery.sizeOf(context);
    final isLast = _step >= widget.targets.length - 1;

    // Prefer card below the hole; flip above if near bottom.
    final holeBottom = rect?.bottom ?? size.height * 0.35;
    final showBelow = holeBottom < size.height * 0.55;
    final cardTop = showBelow
        ? (rect?.bottom ?? 120) + 16
        : null;
    final cardBottom = showBelow
        ? null
        : size.height - (rect?.top ?? size.height * 0.45) + 16;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(hole: rect),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // block taps outside
              ),
            ),
          ),
          if (rect != null)
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            top: cardTop,
            bottom: cardBottom,
            child: _CoachCard(
              step: _step + 1,
              total: widget.targets.length,
              title: target.title,
              body: target.body,
              primaryLabel: isLast ? l.coachDone : l.coachNext,
              skipLabel: l.coachSkip,
              onSkip: () => Navigator.of(context).pop(),
              onPrimary: () {
                if (isLast) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _step++);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String body;
  final String primaryLabel;
  final String skipLabel;
  final VoidCallback onSkip;
  final VoidCallback onPrimary;

  const _CoachCard({
    required this.step,
    required this.total,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.skipLabel,
    required this.onSkip,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$step / $total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    skipLabel,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      final cut = Path()
        ..addRRect(
          RRect.fromRectAndRadius(hole!, const Radius.circular(14)),
        );
      canvas.drawPath(
        Path.combine(PathOperation.difference, overlay, cut),
        Paint()..color = Colors.black.withValues(alpha: 0.72),
      );
    } else {
      canvas.drawPath(
        overlay,
        Paint()..color = Colors.black.withValues(alpha: 0.72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole;
}
