import 'package:flutter/material.dart';

class ThemePreset {
  final String id;
  final String name;
  final Color primaryColor;
  final Color headerColor;
  final Color accentColor;

  /// Dark presets force the whole app into dark mode while selected.
  final bool isDark;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.headerColor,
    required this.accentColor,
    this.isDark = false,
  });
}
