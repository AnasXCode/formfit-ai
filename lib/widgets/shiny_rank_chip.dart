import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The "Rank #4" pill on the Home screen.
///
/// When [shiny] is true a bright glint sweeps across the text and icon every
/// couple of seconds, and the border glows softly. When false (for example
/// "Unranked") it is a plain, still pill.
class ShinyRankChip extends StatefulWidget {
  const ShinyRankChip({
    super.key,
    required this.label,
    required this.shiny,
    this.onTap,
  });

  final String label;
  final bool shiny;
  final VoidCallback? onTap;

  @override
  State<ShinyRankChip> createState() => _ShinyRankChipState();
}

class _ShinyRankChipState extends State<ShinyRankChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.shiny) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant ShinyRankChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shiny && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.shiny && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.titleMedium;

    if (!widget.shiny) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.military_tech_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(widget.label, style: textStyle),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // The glint crosses the chip during the first 60% of each cycle,
          // then pauses.
          final sweep = (t / 0.6).clamp(0.0, 1.0);
          final slide = -1.2 + 2.4 * Curves.easeInOut.transform(sweep);
          // Soft breathing glow around the chip.
          final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * t);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.45 + 0.35 * pulse),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.10 + 0.22 * pulse),
                  blurRadius: 8 + 8 * pulse,
                ),
              ],
            ),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  AppColors.accent,
                  AppColors.gold,
                  Colors.white,
                  AppColors.gold,
                  AppColors.accent,
                ],
                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                transform: _SlideGradientTransform(slide),
              ).createShader(bounds),
              child: child,
            ),
          );
        },
        // The content is built once; only the shader and glow animate.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.military_tech_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(widget.label, style: textStyle?.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// Slides a gradient sideways by a fraction of its width.
class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}