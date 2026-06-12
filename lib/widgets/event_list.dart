import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/holiday.dart';
import '../providers/settings_provider.dart';

class EventList extends StatelessWidget {
  final List<Holiday> holidays;
  final DateTime? selectedDate;

  const EventList({super.key, required this.holidays, this.selectedDate});

  static const _liburColor = Color(0xFFE53935);
  static const _cutiColor = Color(0xFFF57C00);
  static const _hbnColor = Color(0xFF1565C0);
  static const _hbiColor = Color(0xFF7B1FA2);

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

  Map<DateTime, List<Holiday>> _groupByDate() {
    final map = <DateTime, List<Holiday>>{};
    for (final h in holidays) {
      final key = DateTime(h.date.year, h.date.month, h.date.day);
      (map[key] ??= []).add(h);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(sorted);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final fontWeight = settings.resolvedFontWeight;

    if (holidays.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Tidak ada hari besar bulan ini.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final grouped = _groupByDate();

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
                Text(
                  'Hari Besar & Libur',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, indent: 14, endIndent: 14),
          ...grouped.entries.expand((entry) {
            final date = entry.key;
            final dayHolidays = entry.value;
            final dateStr = DateFormat('EEE, d MMM', 'id').format(date);
            final isHighlighted = selectedDate != null &&
                date.year == selectedDate!.year &&
                date.month == selectedDate!.month &&
                date.day == selectedDate!.day;
            return dayHolidays.asMap().entries.map((e) {
              return _EventTile(
                dateStr: e.key == 0 ? dateStr : '',
                name: e.value.name,
                color: _typeColor(e.value.type),
                isFirst: e.key == 0,
                isLast: e.key == dayHolidays.length - 1,
                isHighlighted: isHighlighted,
                fontWeight: fontWeight,
              );
            });
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final String dateStr;
  final String name;
  final Color color;
  final bool isFirst;
  final bool isLast;
  final bool isHighlighted;
  final FontWeight fontWeight;

  const _EventTile({
    required this.dateStr,
    required this.name,
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.fontWeight,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.fromLTRB(8, isFirst ? 6 : 1, 8, isLast ? 4 : 1),
      decoration: isHighlighted
          ? BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(6, isFirst ? 6 : 2, 6, isLast ? 4 : 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                dateStr,
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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: fontWeight,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
