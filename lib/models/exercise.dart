import 'package:flutter/material.dart';

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.icon,
    required this.available,
    this.subtitle,
    this.iconBuilder,
  });

  final String id;
  final String name;
  final IconData icon;
  final bool available;
  final String? subtitle;

  /// Optional custom icon (for example a drawn push-up figure). When set it is
  /// used instead of [icon], which stays as the fallback.
  final Widget Function(Color color, double size)? iconBuilder;
}