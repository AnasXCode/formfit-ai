import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular avatar. What it shows, in order:
///  1. [photoBase64] - the photo the user picked from the gallery
///  2. [photoUrl]    - the Google account photo
///  3. [initials] on a coloured background
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.photoBase64,
    this.avatarColorHex,
    this.radius = 26,
    this.fontSize = 16,
  });

  final String initials;
  final String? photoUrl;
  final String? photoBase64;
  final String? avatarColorHex;
  final double radius;
  final double fontSize;

  // Decoding a base64 string on every rebuild would make the image flicker
  // (a new byte list is a new image), so decoded photos are remembered.
  static final Map<String, Uint8List> _decoded = <String, Uint8List>{};

  static Uint8List? decodePhoto(String? base64Photo) {
    final value = base64Photo?.trim();
    if (value == null || value.isEmpty) return null;
    final cached = _decoded[value];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(value);
      if (_decoded.length >= 6) _decoded.clear();
      _decoded[value] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    final bytes = decodePhoto(photoBase64);
    final size = radius * 2;
    final accent = AppColors.tryParseHex(avatarColorHex) ?? AppColors.accent;

    Widget fallback() => _Fallback(
      initials: initials,
      fontSize: fontSize,
      radius: radius,
      accent: accent,
    );

    Widget child;
    if (bytes != null) {
      child = Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    } else if (hasUrl) {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback();
        },
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    } else {
      child = fallback();
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: accent.withValues(alpha: 0.18),
          child: child,
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
    required this.accent,
  });

  final String initials;
  final double fontSize;
  final double radius;
  final Color accent;

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
            color: accent,
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.person_rounded,
        color: accent,
        size: radius,
      ),
    );
  }
}