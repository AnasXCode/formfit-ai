import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_stats_provider.dart';
import '../theme/app_colors.dart';

/// "Today's goal" ring shown on the Home screen: how many of today's target
/// reps are done. Tap it to change the target.
class DailyGoalRing extends ConsumerWidget {
  const DailyGoalRing({super.key, required this.todayReps});

  final int todayReps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(dailyGoalProvider);
    final scheme = Theme.of(context).colorScheme;
    final progress = goal <= 0 ? 0.0 : (todayReps / goal).clamp(0.0, 1.0);
    final done = todayReps >= goal;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _editGoal(context, ref, goal),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(64),
                    painter: _RingPainter(
                      progress: progress,
                      trackColor: scheme.outline.withValues(alpha: 0.35),
                      color: done ? AppColors.success : AppColors.accent,
                    ),
                  ),
                  done
                      ? const Icon(Icons.check_rounded,
                      color: AppColors.success, size: 26)
                      : Text(
                    '${(progress * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's goal",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done
                        ? 'Goal reached — $todayReps reps today!'
                        : '$todayReps of $goal reps',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 18,
              color: scheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, WidgetRef ref, int current) {
    final controller = TextEditingController(text: '$current');
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily rep goal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'reps / day'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                ref.read(dailyGoalProvider.notifier).setGoal(value);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.color,
  });

  final double progress;
  final Color trackColor;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 6.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}