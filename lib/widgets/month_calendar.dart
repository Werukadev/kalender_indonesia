import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/holiday.dart';
import '../providers/settings_provider.dart';
import '../services/javanese_calendar_service.dart';

class MonthCalendar extends StatelessWidget {
  final int year;
  final int month;
  final List<Holiday> holidays;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDayTap;

  const MonthCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.holidays,
    this.selectedDate,
    this.onDayTap,
  });

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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final showJavanese = settings.showJavaneseCalendar;
    final showCellBorder = settings.showCellBorder;
    final holidayMap = _buildHolidayMap();
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;

    const weekDayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
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
        children: [
          Row(
            children: List.generate(7, (i) {
              final isWeekend = i >= 5;
              return Expanded(
                child: Center(
                  child: Text(
                    weekDayLabels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isWeekend
                          ? Colors.red.shade600
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          const Divider(height: 10, thickness: 0.5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.9,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox.shrink();

              final day = index - startOffset + 1;
              final date = DateTime(year, month, day);
              final dayHolidays = holidayMap[day] ?? [];
              final isWeekend = date.weekday >= 6;
              final isToday = _isToday(date);
              final isSelected = selectedDate != null &&
                  selectedDate!.year == year &&
                  selectedDate!.month == month &&
                  selectedDate!.day == day;

              return _DayCell(
                day: day,
                date: date,
                isWeekend: isWeekend,
                isToday: isToday,
                isSelected: isSelected,
                holidays: dayHolidays,
                settingFontWeight: settings.resolvedFontWeight,
                showJavanese: showJavanese,
                showCellBorder: showCellBorder,
                onTap: () => onDayTap?.call(date),
              );
            },
          ),
        ],
      ),
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
  final bool isWeekend;
  final bool isToday;
  final bool isSelected;
  final List<Holiday> holidays;
  final VoidCallback? onTap;
  final FontWeight settingFontWeight;
  final bool showJavanese;
  final bool showCellBorder;

  const _DayCell({
    required this.day,
    required this.date,
    required this.isWeekend,
    required this.isToday,
    required this.isSelected,
    required this.holidays,
    required this.settingFontWeight,
    required this.showJavanese,
    required this.showCellBorder,
    this.onTap,
  });

  static const _liburColor = Color(0xFFE53935);
  static const _cutiColor = Color(0xFFF57C00);
  static const _hbnColor = Color(0xFF1565C0);
  static const _hbiColor = Color(0xFF7B1FA2);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasLibur = holidays.any((h) => h.type == HolidayType.liburNasional);
    final hasCuti = holidays.any((h) => h.type == HolidayType.cutiBersama);
    final hasHBN = holidays.any((h) => h.type == HolidayType.hariBesarNasional);
    final hasHBI =
        holidays.any((h) => h.type == HolidayType.hariBesarInternasional);

    Color textColor;
    if (hasLibur || isWeekend) {
      textColor = _liburColor;
    } else if (hasCuti) {
      textColor = _cutiColor;
    } else {
      textColor = colorScheme.onSurface;
    }

    final fontWeight = isToday || settingFontWeight == FontWeight.bold
        ? FontWeight.bold
        : FontWeight.w500;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.15)
              : null,
          borderRadius: BorderRadius.circular(7),
          border: isToday
              ? Border.all(color: colorScheme.primary, width: 2)
              : isSelected
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : showCellBorder
                      ? Border.all(
                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                          width: 0.5,
                        )
                      : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: fontWeight,
                      fontSize: 13,
                    ),
                  ),
                  if (showJavanese)
                    Text(
                      getPasaran(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.7),
                        height: 1.1,
                        letterSpacing: 0,
                      ),
                      overflow: TextOverflow.clip,
                    ),
                ],
              ),
            ),
            if (hasHBN || hasHBI)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasHBN)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(left: 1),
                        decoration: const BoxDecoration(
                          color: _hbnColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (hasHBI)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(left: 1),
                        decoration: const BoxDecoration(
                          color: _hbiColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
