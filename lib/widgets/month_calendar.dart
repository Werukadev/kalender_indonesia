import 'package:flutter/material.dart';
import '../models/holiday.dart';

class MonthCalendar extends StatelessWidget {
  final int year;
  final int month;
  final List<Holiday> holidays;

  const MonthCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.holidays,
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
    final holidayMap = _buildHolidayMap();
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Mon=1..Sun=7, offset: Mon=0..Sun=6
    final startOffset = (firstDay.weekday - 1) % 7;

    const weekDayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
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
          // Day of week headers
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
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            }),
          ),
          const Divider(height: 10, thickness: 0.5),
          // Calendar grid
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
              final isWeekend = date.weekday >= 6; // Sat=6, Sun=7
              final isToday = _isToday(date);

              return _DayCell(
                day: day,
                isWeekend: isWeekend,
                isToday: isToday,
                holidays: dayHolidays,
              );
            },
          ),
          const SizedBox(height: 8),
          _CalendarLegend(),
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

class _CalendarLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: const [
          _LegendItem(
            color: Color(0xFFE53935),
            label: 'Libur Nasional',
            isBox: true,
          ),
          _LegendItem(
            color: Color(0xFFF57C00),
            label: 'Cuti Bersama',
            isBox: true,
          ),
          _LegendItem(
            color: Color(0xFF1565C0),
            label: 'Hari Besar Nasional',
          ),
          _LegendItem(
            color: Color(0xFF7B1FA2),
            label: 'Hari Besar Internasional',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isBox;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isBox = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBox)
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          )
        else
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87)),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isWeekend;
  final bool isToday;
  final List<Holiday> holidays;

  const _DayCell({
    required this.day,
    required this.isWeekend,
    required this.isToday,
    required this.holidays,
  });

  static const _liburColor = Color(0xFFE53935);
  static const _cutiColor = Color(0xFFF57C00);
  static const _hbnColor = Color(0xFF1565C0);
  static const _hbiColor = Color(0xFF7B1FA2);

  @override
  Widget build(BuildContext context) {
    final hasLibur = holidays.any((h) => h.type == HolidayType.liburNasional);
    final hasCuti = holidays.any((h) => h.type == HolidayType.cutiBersama);
    final hasHBN = holidays.any((h) => h.type == HolidayType.hariBesarNasional);
    final hasHBI =
        holidays.any((h) => h.type == HolidayType.hariBesarInternasional);

    Color? bgColor;
    Color textColor;

    if (hasLibur) {
      bgColor = _liburColor;
      textColor = Colors.white;
    } else if (hasCuti) {
      bgColor = _cutiColor;
      textColor = Colors.white;
    } else if (isWeekend) {
      textColor = _liburColor;
    } else {
      textColor = Colors.black87;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
        border: isToday
            ? Border.all(
                color: bgColor != null
                    ? Colors.white.withValues(alpha: 0.8)
                    : const Color(0xFFCC0001),
                width: 2,
              )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: textColor,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          if (hasHBN || hasHBI)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasHBN)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        color: _hbnColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (hasHBI)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
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
    );
  }
}
