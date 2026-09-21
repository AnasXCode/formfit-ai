import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onStart,
  });

  final Exercise exercise;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = exercise.available;
    final iconColor =
    enabled ? AppColors.accent : scheme.onSurface.withValues(alpha: 0.5);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: enabled ? scheme.surface : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: enabled
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outline.withValues(alpha: 0.6),
          ),
          boxShadow: enabled
              ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.accent.withValues(alpha: 0.16)
                    : scheme.outline.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: exercise.iconBuilder != null
                  ? Center(child: exercise.iconBuilder!(iconColor, 30))
                  : Icon(exercise.icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exercise.subtitle ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (enabled)
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(88, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('Start'),
              )
            else
              Text(
                'Soon',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}