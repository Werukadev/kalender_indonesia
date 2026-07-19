import 'package:flutter/material.dart';
import '../models/theme_preset.dart';

const List<ThemePreset> kThemePresets = [
  ThemePreset(
    id: 'classic_brown',
    name: 'Classic Brown',
    primaryColor: Color(0xFF8D5248),
    headerColor: Color(0xFFA16357),
    accentColor: Color(0xFFC58A7C),
  ),
  ThemePreset(
    id: 'sage_green',
    name: 'Sage Green',
    primaryColor: Color(0xFF6B8F71),
    headerColor: Color(0xFF7FA67F),
    accentColor: Color(0xFFA8C5A8),
  ),
  ThemePreset(
    id: 'olive_green',
    name: 'Olive Green',
    primaryColor: Color(0xFF708238),
    headerColor: Color(0xFF8DA05B),
    accentColor: Color(0xFFB7C48A),
  ),
  ThemePreset(
    id: 'forest_green',
    name: 'Forest Green',
    primaryColor: Color(0xFF4F6F52),
    headerColor: Color(0xFF739072),
    accentColor: Color(0xFFA8CFA8),
  ),
  ThemePreset(
    id: 'dusty_blue',
    name: 'Dusty Blue',
    primaryColor: Color(0xFF5E81AC),
    headerColor: Color(0xFF81A1C1),
    accentColor: Color(0xFFB9D2EA),
  ),
  ThemePreset(
    id: 'lavender',
    name: 'Lavender',
    primaryColor: Color(0xFF7B6D8D),
    headerColor: Color(0xFF9A8CAF),
    accentColor: Color(0xFFC8BED8),
  ),
  ThemePreset(
    id: 'terracotta',
    name: 'Terracotta',
    primaryColor: Color(0xFFA2675B),
    headerColor: Color(0xFFC17F73),
    accentColor: Color(0xFFE2B3A9),
  ),
  ThemePreset(
    id: 'sand_beige',
    name: 'Sand Beige',
    primaryColor: Color(0xFFA68A64),
    headerColor: Color(0xFFC0A27A),
    accentColor: Color(0xFFE2D0B5),
  ),
  ThemePreset(
    id: 'midnight_dark',
    name: 'Midnight Dark',
    primaryColor: Color(0xFF232936),
    headerColor: Color(0xFF303948),
    accentColor: Color(0xFF7FB5B5),
    isDark: true,
  ),
];
