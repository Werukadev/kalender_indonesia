import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/holiday.dart';
import '../providers/settings_provider.dart';
import '../services/device_calendar_service.dart';
import '../services/javanese_calendar_service.dart';

/// Samsung-Calendar-style month grid: week rows stretch to fill the
/// available height, so this widget must be given bounded height
/// (e.g. wrapped in an [Expanded]).
class MonthCalendar extends StatelessWidget {
  final int year;
  final int month;
  final List<Holiday> holidays;
  final List<DeviceCalendarEvent> deviceEvents;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDayTap;

  const MonthCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.holidays,
    this.deviceEvents = const [],
    this.selectedDate,
    this.onDayTap,
  });

  static const _saturdayColor = Color(0xFF1E6FD9);
  static const _sundayColor = Color(0xFFE53935);

  Map<int, List<Holiday>> _buildHolidayMap() {
    final map = <int, List<Holiday>>{};
    for (final h in holidays) {
      if (h.date.year == year && h.date.month == month) {
        final day = h.date.day;
        (map[day] ??= []).add(h);
      }
    }
    return map;
  }

  Map<int, int> _buildDeviceEventCountMap() {
    final map = <int, int>{};
    for (final e in deviceEvents) {
      final start = e.startDateTime;
      if (start == null || start.year != year || start.month != month) continue;
      map[start.day] = (map[start.day] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final showJavanese = settings.showJavaneseCalendar;
    final showCellBorder = settings.showCellBorder;
    final holidayMap = _buildHolidayMap();
    final deviceEventCountMap = _buildDeviceEventCountMap();
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    const weekDayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List.generate(7, (i) {
              final Color labelColor;
              if (i == 6) {
                labelColor = _sundayColor;
              } else if (i == 5) {
                labelColor = _saturdayColor;
              } else {
                labelColor = colorScheme.onSurface.withValues(alpha: 0.5);
              }
              return Expanded(
                child: Center(
                  child: Text(
                    weekDayLabels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      color: labelColor,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = constraints.maxWidth / 7;
              final cellHeight = constraints.maxHeight / rowCount;
              return GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: cellWidth / cellHeight,
                ),
                itemCount: rowCount * 7,
                itemBuilder: (context, index) {
                  // DateTime normalizes out-of-range days, so day 0 becomes
                  // the last day of the previous month and day 32 rolls into
                  // the next month — giving us the gray outside dates.
                  final date = DateTime(year, month, index - startOffset + 1);
                  final isOutside = date.month != month;
                  final day = date.day;
                  final dayHolidays =
                      isOutside ? const <Holiday>[] : holidayMap[day] ?? [];
                  final isToday = !isOutside && _isToday(date);
                  final isSelected = !isOutside &&
                      selectedDate != null &&
                      selectedDate!.year == year &&
                      selectedDate!.month == month &&
                      selectedDate!.day == day;

                  return _DayCell(
                    day: day,
                    date: date,
                    isToday: isToday,
                    isSelected: isSelected,
                    isOutside: isOutside,
                    holidays: dayHolidays,
                    hasDeviceEvent: !isOutside &&
                        (deviceEventCountMap[day] ?? 0) > 0,
                    settingFontWeight: settings.resolvedFontWeight,
                    showJavanese: showJavanese,
                    showCellBorder: showCellBorder,
                    onTap: () => onDayTap?.call(date),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;
  final List<Holiday> holidays;
  final bool hasDeviceEvent;
  final VoidCallback? onTap;
  final FontWeight settingFontWeight;
  final bool showJavanese;
  final bool showCellBorder;

  const _DayCell({
    required this.day,
    required this.date,
    required this.isToday,
    required this.isSelected,
    this.isOutside = false,
    required this.holidays,
    this.hasDeviceEvent = false,
    required this.settingFontWeight,
    required this.showJavanese,
    required this.showCellBorder,
    this.onTap,
  });

  static const _liburColor = Color(0xFFE53935);
  static const _cutiColor = Color(0xFFF57C00);
  static const _hbnColor = Color(0xFF1565C0);
  static const _hbiColor = Color(0xFF7B1FA2);
  static const _deviceEventColor = Color(0xFF00897B);
  static const _saturdayColor = Color(0xFF1E6FD9);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasLibur = holidays.any((h) => h.type == HolidayType.liburNasional);
    final hasCuti = holidays.any((h) => h.type == HolidayType.cutiBersama);
    final hasHBN = holidays.any((h) => h.type == HolidayType.hariBesarNasional);
    final hasHBI =
        holidays.any((h) => h.type == HolidayType.hariBesarInternasional);
    final isSunday = date.weekday == DateTime.sunday;
    final isSaturday = date.weekday == DateTime.saturday;

    Color textColor;
    if (isOutside) {
      textColor = colorScheme.onSurface.withValues(alpha: 0.25);
    } else if (hasLibur || isSunday) {
      textColor = _liburColor;
    } else if (hasCuti) {
      textColor = _cutiColor;
    } else if (isSaturday) {
      textColor = _saturdayColor;
    } else {
      textColor = colorScheme.onSurface;
    }

    final fontWeight = isToday || settingFontWeight == FontWeight.bold
        ? FontWeight.bold
        : FontWeight.w500;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: showCellBorder
            ? BoxDecoration(
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              )
            : null,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: isToday
                        ? BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          )
                        : isSelected
                            ? BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              )
                            : null,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isToday ? Colors.white : textColor,
                        fontWeight: fontWeight,
                        fontSize: 13,
                        height: 1.0,
                      ),
                    ),
                  ),
                  if (showJavanese)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        getPasaran(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: textColor.withValues(alpha: 0.7),
                          height: 1.0,
                          letterSpacing: 0,
                        ),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                ],
              ),
            ),
            if (hasHBN || hasHBI || hasDeviceEvent)
              Positioned(
                bottom: 3,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasHBN) const _EventDot(_hbnColor),
                    if (hasHBI) const _EventDot(_hbiColor),
                    if (hasDeviceEvent) const _EventDot(_deviceEventColor),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventDot extends StatelessWidget {
  final Color color;

  const _EventDot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
