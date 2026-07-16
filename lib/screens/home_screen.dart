import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/holiday.dart';
import '../providers/device_calendar_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/app_settings_launcher.dart';
import '../services/device_calendar_service.dart';
import '../widgets/month_calendar.dart';
import '../widgets/event_list.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _scrollController = ScrollController();
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  List<Holiday>? _holidays;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  bool _isOfflineCache = false;
  DateTime? _cacheTimestamp;
  double _dragStartX = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadHolidays();
    _loadDeviceEvents();
  }

  void _loadDeviceEvents() {
    context
        .read<DeviceCalendarProvider>()
        .loadMonth(_currentMonth.year, _currentMonth.month);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onDayTap(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Keeps the selected day-of-month when switching months, clamped to the
  /// new month's day count (e.g. selecting the 31st then moving to Feb).
  void _carrySelectedDateToMonth(DateTime newMonth) {
    final daysInNewMonth = DateTime(newMonth.year, newMonth.month + 1, 0).day;
    final day = _selectedDate.day.clamp(1, daysInNewMonth);
    _selectedDate = DateTime(newMonth.year, newMonth.month, day);
  }

  Future<void> _loadHolidays() async {
    _error = null;

    // Phase 1: show cached data immediately — no spinner if cache exists
    final cached =
        await _api.getCached(_currentMonth.year, _currentMonth.month);
    if (!mounted) return;

    if (cached != null) {
      setState(() {
        _holidays = cached.holidays;
        _isOfflineCache = false;
        _cacheTimestamp = cached.cachedAt;
        _isLoading = false;
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _isRefreshing = false;
      });
    }

    // Phase 2: refresh from network silently in background
    try {
      final fresh =
          await _api.fetchFresh(_currentMonth.year, _currentMonth.month);
      if (!mounted) return;
      setState(() {
        _holidays = fresh.holidays;
        _isOfflineCache = false;
        _cacheTimestamp = null;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        if (_holidays != null) {
          // Keep showing cached data, just flag as offline
          _isOfflineCache = true;
        } else {
          _error = e.toString();
        }
      });
    }
  }

  void _resetMonthState() {
    _holidays = null;
    _isOfflineCache = false;
    _cacheTimestamp = null;
    _isRefreshing = false;
    _error = null;
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _carrySelectedDateToMonth(_currentMonth);
      _resetMonthState();
    });
    _loadHolidays();
    _loadDeviceEvents();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _carrySelectedDateToMonth(_currentMonth);
      _resetMonthState();
    });
    _loadHolidays();
    _loadDeviceEvents();
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month);
    if (today != _currentMonth) {
      setState(() {
        _currentMonth = today;
        _selectedDate = DateTime(now.year, now.month, now.day);
        _resetMonthState();
      });
      _loadHolidays();
      _loadDeviceEvents();
    } else {
      setState(() => _selectedDate = DateTime(now.year, now.month, now.day));
    }
  }

  Future<void> _selectYear(BuildContext context) async {
    final preset =
        Provider.of<SettingsProvider>(context, listen: false).selectedPreset;
    final primaryColor = preset.primaryColor;
    final currentYear = _currentMonth.year;
    const firstYear = 2010;
    final lastYear = DateTime.now().year + 5;

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Tahun',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 280,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: lastYear - firstYear + 1,
                    itemBuilder: (_, i) {
                      final year = firstYear + i;
                      final isSelected = year == currentYear;
                      return GestureDetector(
                        onTap: () => Navigator.pop(ctx, year),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.grey.shade300,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$year',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && selected != currentYear) {
      setState(() {
        _currentMonth = DateTime(selected, _currentMonth.month);
        _carrySelectedDateToMonth(_currentMonth);
        _resetMonthState();
      });
      _loadHolidays();
      _loadDeviceEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final preset = settings.selectedPreset;
    final filteredHolidays = (_holidays ?? [])
        .where((h) => settings.isTypeVisible(h.type))
        .toList();
    final deviceCalendar = context.watch<DeviceCalendarProvider>();
    final deviceEvents =
        deviceCalendar.eventsFor(_currentMonth.year, _currentMonth.month);
    // Only an explicit `false` should show the banner — while null (still
    // resolving, or never requested yet), it's usually just a split-second
    // permission lookup, not a genuine denial.
    final calendarPermissionDenied = deviceCalendar.permissionGranted == false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: GestureDetector(
          onHorizontalDragStart: (d) => _dragStartX = d.globalPosition.dx,
          onHorizontalDragEnd: (d) {
            final dx = d.globalPosition.dx - _dragStartX;
            if (dx < -50) _nextMonth();
            if (dx > 50) _prevMonth();
          },
          child: _buildBody(
            preset.primaryColor,
            filteredHolidays,
            deviceEvents,
            calendarPermissionDenied,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    Color headerColor,
    List<Holiday> holidays,
    List<DeviceCalendarEvent> deviceEvents,
    bool calendarPermissionDenied,
  ) {
    final size = MediaQuery.of(context).size;
    final isTabletLandscape =
        size.shortestSide >= 600 && size.width > size.height;

    final header = _MonthHeader(
      currentMonth: _currentMonth,
      onSettingsTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
      onTodayTap: _goToToday,
      onYearTap: () => _selectYear(context),
      headerColor: headerColor,
      isRefreshing: _isRefreshing,
    );

    final calendar = MonthCalendar(
      year: _currentMonth.year,
      month: _currentMonth.month,
      holidays: holidays,
      deviceEvents: deviceEvents,
      selectedDate: _selectedDate,
      onDayTap: _onDayTap,
    );

    // Holiday area: loading card / error card / event list
    final Widget holidaySection = _isLoading
        ? const _HolidayLoadingCard()
        : _error != null
            ? _HolidayErrorCard(onRetry: _loadHolidays)
            : EventList(
                holidays: holidays,
                deviceEvents: deviceEvents,
                selectedDate: _selectedDate,
              );

    final permissionBanner = calendarPermissionDenied
        ? _CalendarPermissionBanner(
            onRefresh: () => context
                .read<DeviceCalendarProvider>()
                .refresh(_currentMonth.year, _currentMonth.month),
          )
        : null;

    if (isTabletLandscape) {
      return Column(
        children: [
          header,
          ?permissionBanner,
          if (_isOfflineCache) _OfflineBanner(cachedAt: _cacheTimestamp),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: calendar,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.12),
                ),
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: holidaySection,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          header,
          ?permissionBanner,
          if (_isOfflineCache) _OfflineBanner(cachedAt: _cacheTimestamp),
          calendar,
          holidaySection,
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CalendarPermissionBanner extends StatelessWidget {
  const _CalendarPermissionBanner({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Colors.red.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.event_busy, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Izin kalender ditolak — event dari kalender perangkat tidak ditampilkan.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              onRefresh();
            },
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Pengaturan', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final DateTime? cachedAt;

  const _OfflineBanner({this.cachedAt});

  @override
  Widget build(BuildContext context) {
    String label = 'Data dari cache tersimpan';
    if (cachedAt != null) {
      final d = cachedAt!;
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 60) {
        label = 'Cache · ${diff.inMinutes} menit lalu';
      } else if (diff.inHours < 24) {
        label = 'Cache · ${diff.inHours} jam lalu';
      } else {
        label = 'Cache · ${diff.inDays} hari lalu';
      }
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF8E1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 13, color: Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF92400E),
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HolidayLoadingCard extends StatelessWidget {
  const _HolidayLoadingCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(vertical: 28),
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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Memuat hari besar...',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HolidayErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _HolidayErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gagal memuat data hari besar',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onSettingsTap;
  final VoidCallback onTodayTap;
  final VoidCallback onYearTap;
  final Color headerColor;
  final bool isRefreshing;

  const _MonthHeader({
    required this.currentMonth,
    required this.onSettingsTap,
    required this.onTodayTap,
    required this.onYearTap,
    required this.headerColor,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'id').format(currentMonth);
    // Container paints the color behind the status bar too (edge-to-edge,
    // no separate AppBar); SafeArea only pads the row content below it.
    return Container(
      color: headerColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'Pengaturan',
                onPressed: onSettingsTap,
                splashRadius: 20,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onYearTap,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        monthName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (isRefreshing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white60),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.today_outlined, color: Colors.white),
                tooltip: 'Hari Ini',
                onPressed: onTodayTap,
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
