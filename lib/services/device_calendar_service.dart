import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';

import 'app_timezone.dart';

/// Read-only import of whatever calendars are synced into the device's
/// native Calendar app (Google, Outlook/Exchange, Samsung, iCloud, local) —
/// via `device_calendar`, not any one provider's own API. This sits
/// alongside [ApiService]'s cal.weruka.dev holiday data; it doesn't touch
/// or replace it.
///
/// All methods are permission-gated and fail soft (return null/empty/false)
/// — a denied calendar permission must never break the holiday calendar.
class DeviceCalendarService {
  // `shouldInitTimezone: false` — device_calendar's default constructor
  // calls `tz.initializeTimeZones()` itself, which unconditionally resets
  // the global `tz.local` back to plain UTC as a side effect every time it
  // runs, silently undoing `AppTimezone.initialize()`'s correct detection
  // the moment this service is first constructed. See a sibling app's
  // "Calendar module" docs for the full story on this bug.
  final _plugin = DeviceCalendarPlugin(shouldInitTimezone: false);

  Future<bool> _ensurePermissions() async {
    try {
      final has = await _plugin.hasPermissions();
      if (has.isSuccess && (has.data ?? false)) return true;
      final requested = await _plugin.requestPermissions();
      return requested.isSuccess && (requested.data ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Checks (without requesting) whether calendar permission is currently
  /// granted — lets callers tell "permission denied" apart from "genuinely
  /// no device events this month", which otherwise look identical.
  Future<bool> hasCalendarPermission() async {
    try {
      final result = await _plugin.hasPermissions();
      return result.isSuccess && (result.data ?? false);
    } catch (_) {
      return false;
    }
  }

  Future<List<Calendar>> _calendars() async {
    try {
      final result = await _plugin.retrieveCalendars();
      // The plugin reports most failures through the Result object, not
      // exceptions — surfacing them is the only way to see why a synced
      // account's calendars are missing.
      if (!result.isSuccess) {
        debugPrint('DeviceCalendarService._calendars errors: '
            '${result.errors.map((e) => e.errorMessage).join('; ')}');
      }
      final calendars = result.data?.toList() ?? const <Calendar>[];
      for (final c in calendars) {
        debugPrint('DeviceCalendarService: calendar "${c.name}" '
            'account="${c.accountName}" type="${c.accountType}" '
            'id=${c.id}');
      }
      return calendars;
    } catch (e) {
      debugPrint('DeviceCalendarService._calendars failed: $e');
      return const [];
    }
  }

  /// Events from every visible device calendar within `[from, to]`.
  Future<List<DeviceCalendarEvent>> listEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!await _ensurePermissions()) return const [];
    // `.toLocal()` below reads the `timezone` package's global `tz.local`
    // — without waiting for this, an early call (before
    // `AppTimezone.initialize()`'s fire-and-forget call from `main.dart`
    // has finished) would silently convert against the package's UTC
    // default instead of the device's real zone.
    await AppTimezone.ready;

    final calendars = await _calendars();
    final params = RetrieveEventsParams(startDate: from, endDate: to);
    final events = <DeviceCalendarEvent>[];
    for (final cal in calendars) {
      if (cal.id == null) continue;
      try {
        final result = await _plugin.retrieveEvents(cal.id, params);
        if (!result.isSuccess) {
          debugPrint('DeviceCalendarService.listEvents: calendar '
              '"${cal.name}" returned errors: '
              '${result.errors.map((e) => e.errorMessage).join('; ')}');
        }
        for (final e in result.data ?? const <Event>[]) {
          if (e.eventId == null) continue;
          events.add(
            DeviceCalendarEvent(
              deviceEventId: e.eventId!,
              title: e.title ?? '',
              startDateTime: e.start?.toLocal(),
              endDateTime: e.end?.toLocal(),
              isAllDay: e.allDay ?? false,
              location: e.location,
              description: e.description,
            ),
          );
        }
      } catch (e) {
        // One calendar failing (e.g. an OEM-specific calendar the plugin
        // can't parse) must not blank out every other calendar's events.
        debugPrint('DeviceCalendarService.listEvents: calendar "${cal.name}" failed: $e');
      }
    }
    return events;
  }
}

/// A trimmed-down read-only view of a native device-calendar event — just
/// enough to show it in the month grid and event list.
class DeviceCalendarEvent {
  const DeviceCalendarEvent({
    required this.deviceEventId,
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
    this.isAllDay = false,
    this.location,
    this.description,
  });

  final String deviceEventId;
  final String title;
  final DateTime? startDateTime;
  final DateTime? endDateTime;

  /// True for a whole-day event (Android/iOS store these at UTC midnight
  /// regardless of the device's own timezone) — [startDateTime] still holds
  /// a real instant, but showing its clock time as-is would display a
  /// bogus, offset-shifted hour instead of "all day".
  final bool isAllDay;
  final String? location;
  final String? description;
}
