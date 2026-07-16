import 'package:flutter/foundation.dart';

import '../services/device_calendar_service.dart';

/// Exposes device-synced calendar events (Google, Outlook, Samsung, etc.)
/// per month, alongside the app's existing cal.weruka.dev holiday data —
/// entirely separate from `ApiService`/`SettingsProvider`, so it can be
/// added or removed without touching the holiday-fetch code path.
class DeviceCalendarProvider extends ChangeNotifier {
  final _service = DeviceCalendarService();
  final Map<String, List<DeviceCalendarEvent>> _cache = {};

  /// Null until the first load attempt resolves; true/false afterward.
  /// Only an explicit `false` should trigger a "permission denied" banner —
  /// while null, it's usually just a split-second permission lookup.
  bool? _permissionGranted;
  bool? get permissionGranted => _permissionGranted;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<DeviceCalendarEvent> eventsFor(int year, int month) =>
      _cache['$year-$month'] ?? const [];

  Future<void> loadMonth(int year, int month) async {
    final key = '$year-$month';
    _isLoading = true;
    notifyListeners();

    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0, 23, 59, 59);
    final events = await _service.listEvents(from: from, to: to);
    _permissionGranted = await _service.hasCalendarPermission();
    _cache[key] = events;
    _isLoading = false;
    notifyListeners();
  }

  /// Re-checks permission and refetches the given month — used when the
  /// user comes back from granting permission in system Settings.
  Future<void> refresh(int year, int month) async {
    _cache.remove('$year-$month');
    await loadMonth(year, month);
  }
}
