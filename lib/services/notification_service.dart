import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/holiday.dart';
import 'api_service.dart';
import 'app_timezone.dart';

/// Local scheduled notifications — no Firebase involved.
///
/// Every time the app runs, upcoming holidays (current + next month) are
/// (re)scheduled as AlarmManager alarms firing at 00:05 local time on each
/// holiday's date. The boot receiver declared in AndroidManifest re-registers
/// alarms after a reboot, and alarms whose time passed while the device was
/// off fire immediately once it turns on.
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
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  static Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  /// Re-syncs all scheduled notifications from the holiday API (current and
  /// next month), replacing any previous schedule. Cache is used when the
  /// network is unavailable. Safe to call fire-and-forget.
  static Future<void> resync(
    ApiService api, {
    required bool enabled,
    required Set<HolidayType> visibleTypes,
  }) async {
    await initialize();
    if (!enabled) {
      await _plugin.cancelAll();
      return;
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
    if (all.isEmpty) return;
    await _schedule(all, visibleTypes: visibleTypes);
  }

  static Future<void> _schedule(
    List<Holiday> holidays, {
    required Set<HolidayType> visibleTypes,
  }) async {
    await AppTimezone.ready;
    await _plugin.cancelAll();

    // One notification per calendar day.
    final byDate = <DateTime, List<Holiday>>{};
    for (final h in holidays) {
      if (!visibleTypes.contains(h.type)) continue;
      final day = DateTime(h.date.year, h.date.month, h.date.day);
      (byDate[day] ??= []).add(h);
    }

    final now = tz.TZDateTime.now(tz.local);
    final dates = byDate.keys.toList()..sort();
    var id = 1000;
    for (final date in dates) {
      final when =
          tz.TZDateTime(tz.local, date.year, date.month, date.day, 0, 5);
      if (!when.isAfter(now)) continue;

      final items = byDate[date]!
        ..sort((a, b) => a.type.sortOrder.compareTo(b.type.sortOrder));
      final title = items.length == 1
          ? items.first.name
          : '${items.length} hari penting hari ini';
      final names = items.map((h) => h.name).join(' • ');
      final desc = items.first.description?.trim();
      final body = items.length == 1
          ? (desc != null && desc.isNotEmpty ? desc : items.first.name)
          : names;

      // If a holiday that day has an image, attach it as a big picture.
      final imagePath = await _downloadImage(items, date);

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: imagePath != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(imagePath),
                summaryText: body,
                contentTitle: title,
              )
            : BigTextStyleInformation(body, contentTitle: title),
      );

      try {
        await _plugin.zonedSchedule(
          id: id++,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } on Exception {
        // Exact alarms not permitted on this device — inexact is fine, the
        // notification still arrives shortly after midnight.
        await _plugin.zonedSchedule(
          id: id++,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  /// Downloads the first available holiday image for [date] into app storage
  /// (a temp dir could be wiped before the alarm fires). Returns null when
  /// no image exists or the download fails — caller falls back to text-only.
  static Future<String?> _downloadImage(
    List<Holiday> items,
    DateTime date,
  ) async {
    final withImage = items.where((h) => h.imageUrl != null).toList();
    if (withImage.isEmpty) return null;
    final url = withImage.first.imageUrl!;
    try {
      final dir = await getApplicationSupportDirectory();
      final imagesDir = Directory('${dir.path}/notif_images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
      final ext = url.split('.').last.split('?').first.toLowerCase();
      final safeExt = const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)
          ? ext
          : 'jpg';
      final file = File(
        '${imagesDir.path}/'
        '${date.year}-${date.month}-${date.day}.$safeExt',
      );
      if (await file.exists()) return file.path;

      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      await file.writeAsBytes(resp.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
