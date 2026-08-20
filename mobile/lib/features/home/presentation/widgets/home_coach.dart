import 'package:flutter/material.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';

/// Bumped for process-oriented first-run tour.
const kHomeCoachDoneKey = 'home_coach_done_v4';

class CoachTarget {
  final GlobalKey key;
  final String title;
  final String body;
  /// Called when this step becomes active (e.g. switch tabs first).
  final Future<void> Function()? onEnter;

  const CoachTarget({
    required this.key,
    required this.title,
    required this.body,
    this.onEnter,
  });
}

Future<bool> isHomeCoachDone() async {
  return await AppSecureStorage.read(kHomeCoachDoneKey) == 'true';
}

Future<void> markHomeCoachDone() async {
  await AppSecureStorage.write(kHomeCoachDoneKey, 'true');
}

/// First-run spotlight tour over the main home buttons.
Future<void> showHomeCoach(
  BuildContext context, {
  required List<CoachTarget> targets,
}) async {
  await showSpotlightCoach(context, targets: targets);
  await markHomeCoachDone();
}

/// Reusable spotlight coach (home + group tours).
Future<void> showSpotlightCoach(
  BuildContext context, {
  required List<CoachTarget> targets,
}) async {
  final usable = targets
      .where((t) => t.key.currentContext?.findRenderObject() != null)
      .toList();
  if (usable.isEmpty) return;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'coach',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) {
      return SizedBox.expand(
        child: _SpotlightCoachDialog(targets: usable),
      );
    },
  );
}

class _SpotlightCoachDialog extends StatefulWidget {
  final List<CoachTarget> targets;
  const _SpotlightCoachDialog({required this.targets});

  @override
  State<_SpotlightCoachDialog> createState() => _SpotlightCoachDialogState();
}

class _SpotlightCoachDialogState extends State<_SpotlightCoachDialog> {
  int _step = 0;
  bool _entering = false;

  static const _cardH = 150.0;
  static const _gap = 10.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runOnEnter());
  }

  Future<void> _runOnEnter() async {
    final enter = widget.targets[_step].onEnter;
    if (enter == null) return;
    setState(() => _entering = true);
    try {
      await enter();
      // Allow layout after tab switch / scroll.
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => _entering = false);
    }
  }

  Rect? _targetRect() {
    final ctx = widget.targets[_step].key.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final offset = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      offset.dx - 6,
      offset.dy - 6,
      box.size.width + 12,
      box.size.height + 12,
    );
  }

  double _cardTop(Size screen, EdgeInsets pad, Rect? rect) {
    final minTop = pad.top + 8;
    final maxTop = screen.height - pad.bottom - _cardH - 8;
    if (rect == null) {
      return (screen.height * 0.32).clamp(minTop, maxTop);
    }

    final spaceBelow = screen.height - pad.bottom - rect.bottom - _gap;
    final spaceAbove = rect.top - pad.top - _gap;

    double top;
    if (spaceBelow >= _cardH) {
      top = rect.bottom + _gap;
    } else if (spaceAbove >= _cardH) {
      top = rect.top - _gap - _cardH;
    } else if (spaceBelow >= spaceAbove) {
      top = rect.bottom + _gap;
    } else {
      top = rect.top - _gap - _cardH;
    }
    return top.clamp(minTop, maxTop);
  }

  void _close() => Navigator.of(context).pop();

  Future<void> _next() async {
    if (_step >= widget.targets.length - 1) {
      _close();
      return;
    }
    setState(() => _step++);
    await _runOnEnter();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final target = widget.targets[_step];
    final rect = _entering ? null : _targetRect();
    final isLast = _step >= widget.targets.length - 1;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final cardTop = _cardTop(size, pad, rect);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
            left: 16,
            right: 16,
            top: cardTop,
            child: _CoachCard(
              step: _step + 1,
              total: widget.targets.length,
              title: target.title,
              body: target.body,
              primaryLabel: isLast ? l.coachDone : l.coachNext,
              closeLabel: l.coachSkip,
              closeTooltip: l.coachCloseTooltip,
              onClose: _close,
              onPrimary: () {
                _next();
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
  final String closeLabel;
  final String closeTooltip;
  final VoidCallback onClose;
  final VoidCallback onPrimary;

  const _CoachCard({
    required this.step,
    required this.total,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.closeLabel,
    required this.closeTooltip,
    required this.onClose,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '$step / $total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: closeTooltip,
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onClose,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          closeLabel,
                          style: const TextStyle(
                            fontSize: 13,
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
                          minimumSize: const Size(96, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          primaryLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      final cut = Path()
        ..addRRect(
          RRect.fromRectAndRadius(hole!, const Radius.circular(12)),
        );
      canvas.drawPath(
        Path.combine(PathOperation.difference, overlay, cut),
        Paint()..color = Colors.black.withValues(alpha: 0.7),
      );
    } else {
      canvas.drawPath(
        overlay,
        Paint()..color = Colors.black.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole;
}
