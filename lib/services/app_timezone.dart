import 'dart:async';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Single source of truth for "what timezone is this device in", used by
/// `DeviceCalendarService` to correctly interpret device-calendar event
/// times (which come back tagged with real IANA zones via the `timezone`
/// package's global `tz.local`).
abstract final class AppTimezone {
  static late tz.Location local;
  static final Completer<void> _ready = Completer<void>();

  /// Resolves once [local] has actually been set. `initialize()` is called
  /// fire-and-forget from `main.dart` — anything that reads device-calendar
  /// events before this resolves would silently compute against the
  /// `timezone` package's own built-in default (UTC) instead of the
  /// device's real zone, showing every event shifted by the device's full
  /// UTC offset.
  static Future<void> get ready => _ready.future;

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.Location? resolved;
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      resolved = tz.getLocation(deviceTimezone.identifier);
    } catch (_) {
      // The platform failed to report a usable IANA identifier at all —
      // handled the same as a wrong one below.
      resolved = null;
    }

    // `flutter_timezone` isn't only capable of throwing — on at least one
    // real device it silently returned "Etc/UTC" while the OS was
    // genuinely configured for a real offset. A wrong-but-resolvable
    // identifier doesn't throw, so the catch above never sees it —
    // cross-checking the resolved zone's *current* offset against Dart's
    // own OS-level offset (`DateTime.now().timeZoneOffset`, no plugin
    // involved, always correct) catches this case too, not just outright
    // plugin failures.
    final deviceOffset = DateTime.now().timeZoneOffset;
    if (resolved == null || resolved.currentTimeZone.offset != deviceOffset) {
      resolved = _bestEffortOffsetMatch(deviceOffset) ?? resolved ?? tz.UTC;
    }

    local = resolved;
    tz.setLocalLocation(local);
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Finds any real IANA zone currently at [deviceOffset] — not
  /// DST-transition-precise, but the wall-clock hour comes out right
  /// immediately, which is what actually matters when the primary
  /// identifier-based detection can't be trusted.
  static tz.Location? _bestEffortOffsetMatch(Duration deviceOffset) {
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.currentTimeZone.offset == deviceOffset) return location;
    }
    return null;
  }
}
