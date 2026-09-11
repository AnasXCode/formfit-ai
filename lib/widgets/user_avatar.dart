import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.radius = 26,
    this.fontSize = 16,
  });

  final String initials;
  final String? photoUrl;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    final size = radius * 2;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: AppColors.accent.withValues(alpha: 0.18),
          child: hasPhoto
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _Fallback(initials: initials, fontSize: fontSize, radius: radius);
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _Fallback(initials: initials, fontSize: fontSize, radius: radius);
                  },
                )
              : _Fallback(initials: initials, fontSize: fontSize, radius: radius),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.initials,
    required this.fontSize,
    required this.radius,
  });

  final String initials;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final label = initials.trim();
    if (label.isNotEmpty) {
      return Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.person_rounded,
        color: AppColors.accent,
        size: radius,
      ),
    );
  }
}
