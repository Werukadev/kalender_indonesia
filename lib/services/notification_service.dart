import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/holiday.dart';
import 'api_service.dart';
import 'app_timezone.dart';
import 'bmkg_service.dart';
import 'offline_cache.dart';

/// Local scheduled notifications — no Firebase involved.
///
/// Every time the app runs, upcoming holidays (current + next month) are
/// (re)scheduled as AlarmManager alarms firing at 00:05 local time on each
/// holiday's date. The boot receiver declared in AndroidManifest re-registers
/// alarms after a reboot, and alarms whose time passed while the device was
/// off fire immediately once it turns on.
///
/// Alarms can still be lost wholesale (aggressive OEM battery killers,
/// force-stop, reinstall after midnight), so resync also has a catch-up
/// path: if *today* has holidays and today's notification never made it to
/// the shade, it is shown immediately — at most once per day, keyed by a
/// deterministic per-date notification id.
abstract final class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'holiday_reminders';
  static const _channelName = 'Pengingat Hari Penting';
  static const _channelDescription =
      'Notifikasi hari libur dan hari besar pada tanggalnya';

  static Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Asks for POST_NOTIFICATIONS (Android 13+). Exact-alarm permission is
  /// auto-granted via USE_EXACT_ALARM for calendar apps.
  static Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Cancels every *scheduled* reminder. Deliberately leaves already-shown
  /// notifications in the shade — cancelAll() would silently dismiss the
  /// midnight notification the moment the user opens the app.
  static Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAllPendingNotifications();
  }

  /// Number of currently scheduled (pending) notifications.
  static Future<int> pendingCount() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  /// Fires an immediate notification so the user can verify that
  /// permissions, the channel, and the icon actually work on this device.
  static Future<void> showTestNotification() async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    try {
      await _plugin.show(
        id: 999,
        title: 'Notifikasi berfungsi 🎉',
        body:
            'Pengingat hari penting akan muncul seperti ini '
            'lewat tengah malam pada tanggalnya.',
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
      debugPrint('NotificationService: test notification show() completed');
    } catch (e, st) {
      debugPrint('NotificationService: test notification FAILED: $e\n$st');
      rethrow;
    }
  }

  /// Re-syncs all scheduled notifications from the holiday API (current and
  /// next month), replacing any previous schedule. Cache is used when the
  /// network is unavailable. Returns how many reminders were scheduled.
  /// Safe to call fire-and-forget.
  static Future<int> resync(
    ApiService api, {
    required bool enabled,
    required Set<HolidayType> visibleTypes,
  }) async {
    await initialize();
    if (!enabled) {
      await _plugin.cancelAllPendingNotifications();
      return 0;
    }

    final now = DateTime.now();
    final months = [
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ];
    final all = <Holiday>[];
    for (final m in months) {
      try {
        final fresh = await api.fetchFresh(m.year, m.month);
        all.addAll(fresh.holidays);
      } catch (_) {
        final cached = await api.getCached(m.year, m.month);
        if (cached != null) all.addAll(cached.holidays);
      }
    }
    if (all.isEmpty) {
      debugPrint('NotificationService: no holiday data to schedule');
      return 0;
    }
    return _schedule(all, visibleTypes: visibleTypes);
  }

  /// Deterministic notification id per calendar day, so the 00:05 alarm
  /// and the catch-up path can never produce two notifications for the
  /// same date (a re-post with the same id replaces, not duplicates).
  static int _idForDate(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Prefs key remembering the last date the catch-up path handled.
  static const _lastCatchUpKey = 'notifLastCatchupDate';

  static Future<int> _schedule(
    List<Holiday> holidays, {
    required Set<HolidayType> visibleTypes,
  }) async {
    await AppTimezone.ready;
    // Pending only — cancelAll() would also dismiss notifications currently
    // sitting in the shade (which is how reminders kept "disappearing").
    await _plugin.cancelAllPendingNotifications();

    // One notification per calendar day.
    final byDate = <DateTime, List<Holiday>>{};
    for (final h in holidays) {
      if (!visibleTypes.contains(h.type)) continue;
      final day = DateTime(h.date.year, h.date.month, h.date.day);
      (byDate[day] ??= []).add(h);
    }

    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    final dates = byDate.keys.toList()..sort();
    var scheduled = 0;
    for (final date in dates) {
      final when = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        0,
        5,
      );

      final items = byDate[date]!
        ..sort((a, b) => a.type.sortOrder.compareTo(b.type.sortOrder));

      // The holiday names must always be visible in the notification —
      // both collapsed (title/body) and expanded (big text / picture).
      final names = items.map((h) => h.name).join(' • ');
      final title = names;
      final desc = items.first.description?.trim();
      final body = items.length == 1
          ? (desc != null && desc.isNotEmpty ? desc : items.first.name)
          : names;
      final bigText = items.length == 1
          ? body
          : items.map((h) => '• ${h.name}').join('\n');

      // If a holiday that day has an image, attach it as a big picture
      // (plus a thumbnail while collapsed).
      final imagePath = await _downloadImage(items);

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: imagePath != null ? FilePathAndroidBitmap(imagePath) : null,
        styleInformation: imagePath != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(imagePath),
                contentTitle: title,
                summaryText: bigText,
                hideExpandedLargeIcon: true,
              )
            : BigTextStyleInformation(bigText, contentTitle: title),
      );
      final details = NotificationDetails(android: androidDetails);
      final id = _idForDate(date);

      if (!when.isAfter(now)) {
        // 00:05 already passed. For today that must not mean silence —
        // the alarm may have been killed before it could fire (reboot,
        // battery saver, app installed after midnight) — so deliver the
        // notification right now instead of skipping the date.
        if (date == today) {
          await _catchUpToday(id, title: title, body: body, details: details);
        }
        continue;
      }

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        scheduled++;
      } catch (e) {
        // Exact alarms not permitted on this device — inexact is fine, the
        // notification still arrives shortly after midnight.
        debugPrint(
          'NotificationService: exact schedule failed ($e), '
          'falling back to inexact',
        );
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: when,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          scheduled++;
        } catch (e) {
          debugPrint('NotificationService: schedule failed entirely: $e');
        }
      }
    }
    debugPrint('NotificationService: $scheduled reminder(s) scheduled');
    return scheduled;
  }

  // Fixed ids for the BMKG alert notifications (replaced in place when a
  // newer alert arrives, never stacking up).
  static const _quakeAlertId = 3001;
  static const _weatherAlertId = 3002;

  static const _bmkgChannelId = 'bmkg_alerts';
  static const _bmkgChannelName = 'Peringatan BMKG';
  static const _bmkgChannelDescription =
      'Gempa signifikan dan peringatan dini cuaca dari BMKG';

  /// Checks BMKG and notifies about (1) a new significant earthquake —
  /// felt by people or M ≥ 5 — and (2) the newest nowcast weather warning.
  /// Deduplicated via SharedPreferences, so each event notifies once.
  ///
  /// No background scheduler is involved: this runs whenever the app
  /// syncs (every open), same as the holiday catch-up path. Fire-and-
  /// forget; failures are silent.
  static Future<void> checkBmkgAlerts() async {
    await initialize();
    try {
      final prefs = await SharedPreferences.getInstance();
      const androidDetails = AndroidNotificationDetails(
        _bmkgChannelId,
        _bmkgChannelName,
        channelDescription: _bmkgChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);

      // 1) Significant earthquake.
      final quake = await BmkgService.latestQuake();
      final significant =
          quake != null &&
          (quake.dirasakan != null || (quake.magnitude ?? 0) >= 5.0);
      if (significant) {
        final key = '${quake.tanggal}|${quake.jam}';
        // Only near-real-time events are worth a notification; opening
        // the app days later must not replay an old quake.
        final recent =
            quake.dateTime != null &&
            DateTime.now().difference(quake.dateTime!).inHours < 24;
        if (recent && prefs.getString('bmkgLastQuakeNotif') != key) {
          final magnitude = quake.magnitude == null
              ? ''
              : 'M${quake.magnitude!.toStringAsFixed(1)} ';
          await _plugin.show(
            id: _quakeAlertId,
            title: '🌏 Gempa $magnitude— ${quake.wilayah}',
            body: [
              '${quake.tanggal} ${quake.jam}',
              if (quake.potensi != null) quake.potensi!,
              if (quake.dirasakan != null) 'Dirasakan: ${quake.dirasakan!}',
            ].join('\n'),
            notificationDetails: details,
          );
          await prefs.setString('bmkgLastQuakeNotif', key);
        }
      }

      // 2) Newest nowcast weather warning.
      final warnings = await BmkgService.nowcastWarnings();
      if (warnings.isNotEmpty) {
        final warning = warnings.first;
        final recent =
            warning.pubDate == null ||
            DateTime.now().difference(warning.pubDate!).inHours < 12;
        if (recent && prefs.getString('bmkgLastWarningNotif') != warning.link) {
          await _plugin.show(
            id: _weatherAlertId,
            title: '⚠️ ${warning.title}',
            body: warning.description,
            notificationDetails: details,
          );
          await prefs.setString('bmkgLastWarningNotif', warning.link);
        }
      }
    } catch (e) {
      debugPrint('NotificationService.checkBmkgAlerts failed: $e');
    }
  }

  /// Shows today's holiday notification immediately if it never reached the
  /// shade — at most once per day. If the 00:05 alarm did fire and its
  /// notification is still visible, only the "handled" marker is written.
  static Future<void> _catchUpToday(
    int id, {
    required String title,
    required String body,
    required NotificationDetails details,
  }) async {
    try {
      final todayKey = DateTime.now().toIso8601String().substring(
        0,
        10,
      ); // yyyy-MM-dd
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_lastCatchUpKey) == todayKey) return;

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final active = await android?.getActiveNotifications();
      final alreadyVisible = active?.any((n) => n.id == id) ?? false;
      if (!alreadyVisible) {
        await _plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: details,
        );
        debugPrint('NotificationService: catch-up notification shown');
      }
      await prefs.setString(_lastCatchUpKey, todayKey);
    } catch (e) {
      debugPrint('NotificationService: catch-up failed: $e');
    }
  }

  /// Local path of the first available holiday image, via [OfflineCache]
  /// (persistent app storage — a temp dir could be wiped before the alarm
  /// fires, and the same file serves the in-app holiday pages offline).
  /// Null when no image exists or the download fails — caller falls back
  /// to text-only.
  static Future<String?> _downloadImage(List<Holiday> items) async {
    final withImage = items.where((h) => h.imageUrl != null).toList();
    if (withImage.isEmpty) return null;
    final file = await OfflineCache.imageFile(withImage.first.imageUrl!);
    return file?.path;
  }
}
