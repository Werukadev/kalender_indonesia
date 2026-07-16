import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/holiday.dart';
import '../providers/settings_provider.dart';
import '../services/device_calendar_service.dart';

/// Shows only [selectedDate]'s events — showing a whole month at once was
/// too much to scan, so the calendar grid picks the day and this just
/// renders that one day's agenda.
class EventList extends StatelessWidget {
  final List<Holiday> holidays;
  final List<DeviceCalendarEvent> deviceEvents;
  final DateTime selectedDate;

  const EventList({
    super.key,
    required this.holidays,
    this.deviceEvents = const [],
    required this.selectedDate,
  });

  static const _liburColor = Color(0xFFE53935);
  static const _cutiColor = Color(0xFFF57C00);
  static const _hbnColor = Color(0xFF1565C0);
  static const _hbiColor = Color(0xFF7B1FA2);
  static const _deviceEventColor = Color(0xFF00897B);

  Color _typeColor(HolidayType type) {
    switch (type) {
      case HolidayType.liburNasional:
        return _liburColor;
      case HolidayType.cutiBersama:
        return _cutiColor;
      case HolidayType.hariBesarNasional:
        return _hbnColor;
      case HolidayType.hariBesarInternasional:
        return _hbiColor;
    }
  }

  bool _isSelectedDay(DateTime d) =>
      d.year == selectedDate.year &&
      d.month == selectedDate.month &&
      d.day == selectedDate.day;

  List<_Entry> _entriesForDay() {
    final entries = <_Entry>[];
    for (final h in holidays) {
      if (_isSelectedDay(h.date)) {
        entries.add(_Entry.holiday(h, _typeColor(h.type)));
      }
    }
    for (final e in deviceEvents) {
      final start = e.startDateTime;
      if (start == null || !_isSelectedDay(start)) continue;
      entries.add(_Entry.device(e, _deviceEventColor));
    }
    entries.sort((a, b) {
      if (a.sortMinutes == null && b.sortMinutes == null) return 0;
      if (a.sortMinutes == null) return -1;
      if (b.sortMinutes == null) return 1;
      return a.sortMinutes!.compareTo(b.sortMinutes!);
    });
    return entries;
  }

  void _showDetail(BuildContext context, _Entry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EventDetailSheet(entry: entry, day: selectedDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final fontWeight = settings.resolvedFontWeight;
    final entries = _entriesForDay();
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id').format(selectedDate);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, indent: 14, endIndent: 14),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Tidak ada kegiatan pada hari ini.',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...entries.asMap().entries.map((e) {
              return _EventTile(
                entry: e.value,
                isFirst: e.key == 0,
                isLast: e.key == entries.length - 1,
                fontWeight: fontWeight,
                onTap: () => _showDetail(context, e.value),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Entry {
  final String name;
  final Color color;
  final bool isDeviceEvent;
  final String? timeLabel;

  /// Minutes since midnight for sort/display; null sorts first (all-day
  /// holidays and all-day device events).
  final int? sortMinutes;
  final String sourceLabel;
  final bool isAllDay;
  final String? location;
  final String? description;
  final DateTime? startDateTime;
  final DateTime? endDateTime;

  const _Entry({
    required this.name,
    required this.color,
    required this.sourceLabel,
    required this.isAllDay,
    this.isDeviceEvent = false,
    this.timeLabel,
    this.sortMinutes,
    this.location,
    this.description,
    this.startDateTime,
    this.endDateTime,
  });

  factory _Entry.holiday(Holiday h, Color color) {
    return _Entry(
      name: h.name,
      color: color,
      sourceLabel: h.type.label,
      isAllDay: true,
      startDateTime: h.date,
    );
  }

  factory _Entry.device(DeviceCalendarEvent e, Color color) {
    final start = e.startDateTime!;
    return _Entry(
      name: e.title.isEmpty ? '(Tanpa judul)' : e.title,
      color: color,
      isDeviceEvent: true,
      sourceLabel: 'Kalender Perangkat',
      isAllDay: e.isAllDay,
      timeLabel: e.isAllDay ? null : DateFormat('HH:mm').format(start),
      sortMinutes: e.isAllDay ? null : start.hour * 60 + start.minute,
      location: e.location,
      description: e.description,
      startDateTime: e.startDateTime,
      endDateTime: e.endDateTime,
    );
  }
}

class _EventTile extends StatelessWidget {
  final _Entry entry;
  final bool isFirst;
  final bool isLast;
  final FontWeight fontWeight;
  final VoidCallback onTap;

  const _EventTile({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.fontWeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.fromLTRB(8, isFirst ? 6 : 1, 8, isLast ? 4 : 1),
        child: Padding(
          padding: EdgeInsets.fromLTRB(6, isFirst ? 6 : 4, 6, isLast ? 6 : 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  entry.timeLabel ?? 'Sehari',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: fontWeight == FontWeight.bold
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  entry.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: fontWeight,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.isDeviceEvent) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.smartphone,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet detail view for one event — works for both a holiday from
/// the cal.weruka.dev API and an event synced from the device calendar.
class _EventDetailSheet extends StatelessWidget {
  final _Entry entry;
  final DateTime day;

  const _EventDetailSheet({required this.entry, required this.day});

  String _timeRangeLabel() {
    if (entry.isAllDay) return 'Sepanjang hari';
    final start = entry.startDateTime;
    final end = entry.endDateTime;
    if (start == null) return '';
    final startStr = DateFormat('HH:mm').format(start);
    if (end == null) return startStr;
    final endStr = DateFormat('HH:mm').format(end);
    return '$startStr – $endStr';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id').format(day);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: entry.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.sourceLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: entry.color,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.calendar_today_outlined, text: dateLabel),
            const SizedBox(height: 10),
            _DetailRow(icon: Icons.access_time, text: _timeRangeLabel()),
            if (entry.location != null && entry.location!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(icon: Icons.place_outlined, text: entry.location!),
            ],
            if (entry.description != null &&
                entry.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.notes_outlined,
                text: entry.description!,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  entry.isDeviceEvent ? Icons.smartphone : Icons.public,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.isDeviceEvent
                      ? 'Dari kalender perangkat'
                      : 'Dari Kalender Indonesia',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}
