import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small side-view push-up figure (head, straight body, arm and floor line)
/// drawn in code, so it works at any size and in any colour.
class PushUpIcon extends StatelessWidget {
  const PushUpIcon({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  /// Matches `Exercise.iconBuilder`, so an exercise can use this icon instead
  /// of a Material icon.
  static Widget builder(Color color, double size) =>
      PushUpIcon(color: color, size: size);

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? Colors.white;
    return CustomPaint(
      size: Size.square(size),
      painter: _PushUpPainter(resolved),
    );
  }
}

class _PushUpPainter extends CustomPainter {
  const _PushUpPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything is drawn on a 24 x 24 grid and scaled to the widget size.
    canvas.scale(size.width / 24, size.height / 24);

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Floor.
    line.strokeWidth = 1.5;
    canvas.drawLine(const Offset(1.5, 21.5), const Offset(22.5, 21.5), line);

    // Body: straight line from the feet up to the shoulders.
    line.strokeWidth = 2.6;
    canvas.drawLine(const Offset(3.5, 19.5), const Offset(16.5, 11.8), line);

    // Arm: straight down from the shoulder to the hand on the floor.
    line.strokeWidth = 2.4;
    canvas.drawLine(const Offset(16.5, 11.8), const Offset(17.2, 20.2), line);

    // Head, in line with the body.
    final fill = Paint()..color = color;
    canvas.drawCircle(
      Offset(16.5 + 3.6 * math.cos(-0.5), 11.8 + 3.6 * math.sin(-0.5)),
      2.3,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PushUpPainter old) => old.color != color;
}