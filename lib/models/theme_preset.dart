import 'package:flutter/material.dart';

class ThemePreset {
  final String id;
  final String name;
  final Color primaryColor;
  final Color headerColor;
  final Color accentColor;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.headerColor,
    required this.accentColor,
  });
}
