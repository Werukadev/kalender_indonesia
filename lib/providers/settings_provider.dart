import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/theme_presets.dart';
import '../models/holiday.dart';
import '../models/theme_preset.dart';

enum AppTextSize { small, medium, big }

enum AppFontWeight { standard, bold }

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppTextSize _textSize = AppTextSize.medium;
  AppFontWeight _fontWeight = AppFontWeight.standard;
  String _selectedThemeId = kThemePresets.first.id;
  Set<HolidayType> _visibleTypes = HolidayType.values.toSet();

  ThemeMode get themeMode => _themeMode;
  AppTextSize get textSize => _textSize;
  AppFontWeight get fontWeight => _fontWeight;
  String get selectedThemeId => _selectedThemeId;
  Set<HolidayType> get visibleTypes => Set.unmodifiable(_visibleTypes);

  ThemePreset get selectedPreset => kThemePresets.firstWhere(
        (p) => p.id == _selectedThemeId,
        orElse: () => kThemePresets.first,
      );

  bool isTypeVisible(HolidayType type) => _visibleTypes.contains(type);

  double get textScale => switch (_textSize) {
    AppTextSize.small => 0.85,
    AppTextSize.medium => 1.0,
    AppTextSize.big => 1.2,
  };

  FontWeight get resolvedFontWeight =>
      _fontWeight == AppFontWeight.bold ? FontWeight.bold : FontWeight.normal;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ti = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    final si = prefs.getInt('textSize') ?? AppTextSize.medium.index;
    final fi = prefs.getInt('fontWeight') ?? AppFontWeight.standard.index;
    final tid = prefs.getString('themeId') ?? kThemePresets.first.id;
    // Default bitmask = all types enabled (2^4 - 1 = 15)
    final vm = prefs.getInt('visibleTypes') ??
        ((1 << HolidayType.values.length) - 1);

    _themeMode = ThemeMode.values[ti.clamp(0, ThemeMode.values.length - 1)];
    _textSize = AppTextSize.values[si.clamp(0, AppTextSize.values.length - 1)];
    _fontWeight =
        AppFontWeight.values[fi.clamp(0, AppFontWeight.values.length - 1)];
    _selectedThemeId =
        kThemePresets.any((p) => p.id == tid) ? tid : kThemePresets.first.id;
    _visibleTypes = _bitmaskToTypes(vm);

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('themeMode', mode.index);
  }

  Future<void> setTextSize(AppTextSize size) async {
    if (_textSize == size) return;
    _textSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('textSize', size.index);
  }

  Future<void> setFontWeight(AppFontWeight weight) async {
    if (_fontWeight == weight) return;
    _fontWeight = weight;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('fontWeight', weight.index);
  }

  Future<void> setThemePreset(String id) async {
    if (_selectedThemeId == id) return;
    _selectedThemeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('themeId', id);
  }

  // Returns false if the toggle was blocked (last enabled type).
  Future<bool> toggleHolidayType(HolidayType type) async {
    final updated = Set<HolidayType>.from(_visibleTypes);
    if (updated.contains(type)) {
      if (updated.length <= 1) return false;
      updated.remove(type);
    } else {
      updated.add(type);
    }
    _visibleTypes = updated;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('visibleTypes', _typesToBitmask(_visibleTypes));
    return true;
  }

  static int _typesToBitmask(Set<HolidayType> types) {
    int mask = 0;
    for (final t in types) {
      mask |= (1 << t.index);
    }
    return mask;
  }

  static Set<HolidayType> _bitmaskToTypes(int mask) {
    final types = <HolidayType>{};
    for (final t in HolidayType.values) {
      if (mask & (1 << t.index) != 0) types.add(t);
    }
    return types.isEmpty ? HolidayType.values.toSet() : types;
  }
}
