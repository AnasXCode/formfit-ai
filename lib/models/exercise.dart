import 'package:flutter/material.dart';

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.icon,
    required this.available,
    this.subtitle,
  });

  final String id;
  final String name;
  final IconData icon;
  final bool available;
  final String? subtitle;
}
