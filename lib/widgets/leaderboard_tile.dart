import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

/// One row of the leaderboard.
///
/// The top 3 get an animated effect, strongest for 1st and weaker for each
/// place after it:
///  * 1st (gold)   - bright diagonal shine sweeping over the whole row, twinkling
///                   sparkles, a strong pulsing glow and a bouncing trophy
///  * 2nd (silver) - a slower, fainter shine, a softer glow and a gentle trophy
///  * 3rd (bronze) - just a soft breathing glow and a tiny trophy pulse
class LeaderboardTile extends StatefulWidget {
  const LeaderboardTile({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  State<LeaderboardTile> createState() => _LeaderboardTileState();
}

class _LeaderboardTileState extends State<LeaderboardTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  _TopEffect? _effect;

  @override
  void initState() {
    super.initState();
    _syncEffect();
  }

  @override
  void didUpdateWidget(covariant LeaderboardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The list can re-rank live, so start / stop the effect when the rank moves.
    if (oldWidget.entry.rank != widget.entry.rank) _syncEffect();
  }

  void _syncEffect() {
    final effect = _TopEffect.forRank(widget.entry.rank);
    _effect = effect;
    if (effect == null) {
      _controller.stop();
      return;
    }
    _controller.duration = effect.period;
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effect = _effect;
    if (effect == null) return _buildTile(context, null, 0);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => _buildTile(context, effect, _controller.value),
    );
  }

  Widget _buildTile(BuildContext context, _TopEffect? effect, double t) {
    final entry = widget.entry;
    final scheme = Theme.of(context).colorScheme;
    final top = entry.rank <= 3;
    final highlight = entry.isCurrentUser;

    // 0..1 breathing value used for the glow.
    final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * t);
    final glow = effect == null
        ? 0.0
        : effect.glowMin + (effect.glowMax - effect.glowMin) * pulse;
    final blur = effect == null
        ? 0.0
        : effect.blurMin + (effect.blurMax - effect.blurMin) * pulse;

    Color? badgeColor;
    switch (entry.rank) {
      case 1:
        badgeColor = AppColors.gold;
      case 2:
        badgeColor = AppColors.silver;
      case 3:
        badgeColor = AppColors.bronze;
    }

    // Trophy: pulses (and on 1st place also wiggles) with the animation.
    Widget rankBadge;
    if (top && effect != null) {
      final scale = 1 + effect.trophyScale * pulse;
      final angle = effect.trophyWiggle * math.sin(2 * math.pi * t * 2);
      rankBadge = Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Icon(Icons.emoji_events_rounded, color: badgeColor, size: 26),
        ),
      );
    } else {
      rankBadge = Text(
        '${entry.rank}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      );
    }

    final Color baseFill = highlight
        ? scheme.primary.withValues(alpha: 0.12)
        : (effect != null
        ? Color.alphaBlend(
      effect.color.withValues(alpha: 0.06),
      scheme.surface,
    )
        : scheme.surface);

    final Color borderColor = highlight
        ? scheme.primary.withValues(alpha: 0.55)
        : (effect != null
        ? effect.color.withValues(alpha: (0.30 + glow).clamp(0.0, 1.0))
        : scheme.outline.withValues(alpha: 0.7));

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 36, child: Center(child: rankBadge)),
          const SizedBox(width: 8),
          UserAvatar(
            radius: 20,
            fontSize: 13,
            initials: entry.initials,
            avatarColorHex: entry.avatarColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (highlight) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${entry.reps}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 4),
          Text('reps', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: baseFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: borderColor, width: highlight ? 1.4 : 1),
        boxShadow: effect == null
            ? null
            : [
          BoxShadow(
            color: effect.color.withValues(alpha: glow),
            blurRadius: blur,
          ),
        ],
      ),
      child: effect == null
          ? content
          : Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _EffectPainter(t: t, effect: effect),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How strong the animation is for one podium place.
class _TopEffect {
  const _TopEffect({
    required this.color,
    required this.period,
    required this.sweepAlpha,
    required this.sweepPortion,
    required this.glowMin,
    required this.glowMax,
    required this.blurMin,
    required this.blurMax,
    required this.trophyScale,
    required this.trophyWiggle,
    required this.sparkles,
  });

  final Color color;

  /// Length of one animation cycle.
  final Duration period;

  /// Brightness of the diagonal shine (0 = no shine at all).
  final double sweepAlpha;

  /// Share of each cycle used for the shine to cross the row (rest is a pause).
  final double sweepPortion;

  final double glowMin;
  final double glowMax;
  final double blurMin;
  final double blurMax;

  /// How much the trophy grows at the peak of its pulse (0.14 = +14%).
  final double trophyScale;

  /// Trophy wiggle in radians.
  final double trophyWiggle;

  /// Twinkling sparkles (1st place only).
  final bool sparkles;

  static _TopEffect? forRank(int rank) {
    switch (rank) {
      case 1:
        return _gold;
      case 2:
        return _silver;
      case 3:
        return _bronze;
      default:
        return null;
    }
  }

  static const _gold = _TopEffect(
    color: AppColors.gold,
    period: Duration(milliseconds: 2600),
    sweepAlpha: 0.32,
    sweepPortion: 0.55,
    glowMin: 0.18,
    glowMax: 0.50,
    blurMin: 10,
    blurMax: 22,
    trophyScale: 0.14,
    trophyWiggle: 0.10,
    sparkles: true,
  );

  static const _silver = _TopEffect(
    color: AppColors.silver,
    period: Duration(milliseconds: 3600),
    sweepAlpha: 0.16,
    sweepPortion: 0.40,
    glowMin: 0.08,
    glowMax: 0.24,
    blurMin: 8,
    blurMax: 14,
    trophyScale: 0.08,
    trophyWiggle: 0,
    sparkles: false,
  );

  static const _bronze = _TopEffect(
    color: AppColors.bronze,
    period: Duration(milliseconds: 4200),
    sweepAlpha: 0,
    sweepPortion: 0.4,
    glowMin: 0.05,
    glowMax: 0.16,
    blurMin: 6,
    blurMax: 10,
    trophyScale: 0.04,
    trophyWiggle: 0,
    sparkles: false,
  );
}

/// Paints the diagonal shine and the sparkles on top of the row.
class _EffectPainter extends CustomPainter {
  const _EffectPainter({required this.t, required this.effect});

  final double t;
  final _TopEffect effect;

  @override
  void paint(Canvas canvas, Size size) {
    if (effect.sweepAlpha > 0) _paintShine(canvas, size);
    if (effect.sparkles) _paintSparkles(canvas, size);
  }

  void _paintShine(Canvas canvas, Size size) {
    final p = (t / effect.sweepPortion).clamp(0.0, 1.0);
    if (p <= 0 || p >= 1) return;
    final eased = Curves.easeInOut.transform(p);

    final band = size.width * 0.28;
    final x = -band + (size.width + 2 * band) * eased;

    canvas.save();
    canvas.translate(x, 0);
    canvas.transform(Matrix4.skewX(-0.4).storage);
    final rect = Rect.fromLTWH(-band / 2, 0, band, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: effect.sweepAlpha),
          effect.color.withValues(alpha: effect.sweepAlpha),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.4, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  void _paintSparkles(Canvas canvas, Size size) {
    // Positions are relative to the row: around the trophy and near the reps.
    final spots = <Offset>[
      Offset(size.width * 0.06, size.height * 0.22),
      Offset(size.width * 0.16, size.height * 0.80),
      Offset(size.width * 0.58, size.height * 0.20),
      Offset(size.width * 0.86, size.height * 0.78),
    ];

    for (var i = 0; i < spots.length; i++) {
      final wave = math.sin(2 * math.pi * (t * 2 + i * 0.27));
      final twinkle = math.pow(math.max(0.0, wave), 3).toDouble();
      if (twinkle < 0.03) continue;

      final paint = Paint()
        ..color = Color.lerp(Colors.white, effect.color, 0.35)!
            .withValues(alpha: twinkle);
      canvas.drawPath(_star(spots[i], 3.5 + 3.5 * twinkle), paint);
    }
  }

  /// A 4-point sparkle star.
  Path _star(Offset c, double r) {
    final path = Path();
    const points = 4;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? r : r * 0.3;
      final angle = -math.pi / 2 + i * math.pi / points;
      final o = Offset(
        c.dx + radius * math.cos(angle),
        c.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _EffectPainter old) =>
      old.t != t || old.effect != effect;
}