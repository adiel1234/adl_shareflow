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
    barrierDismissible: true,
    barrierLabel: 'coach',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) {
      return SizedBox.expand(
        child: _HomeCoachDialog(targets: usable),
      );
    },
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

  void _close() => Navigator.of(context).pop();

  void _next() {
    if (_step >= widget.targets.length - 1) {
      _close();
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final target = widget.targets[_step];
    final rect = _targetRect();
    final isLast = _step >= widget.targets.length - 1;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dimmed backdrop — tap to skip (escape hatch)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: CustomPaint(
                painter: _SpotlightPainter(hole: rect),
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
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ),

          // Card always pinned above the bottom nav / home indicator
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 16,
            child: _CoachCard(
              step: _step + 1,
              total: widget.targets.length,
              title: target.title,
              body: target.body,
              primaryLabel: isLast ? l.coachDone : l.coachNext,
              skipLabel: l.coachSkip,
              onSkip: _close,
              onPrimary: _next,
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
      elevation: 10,
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
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    skipLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
