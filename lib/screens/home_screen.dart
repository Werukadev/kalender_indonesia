import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/holiday.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
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
  DateTime? _selectedDate;
  List<Holiday>? _holidays;
  bool _isLoading = false;
  String? _error;
  bool _isOfflineCache = false;
  DateTime? _cacheTimestamp;
  double _dragStartX = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _loadHolidays();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onDayTap(DateTime date) {
    setState(() {
      _selectedDate = (_selectedDate?.day == date.day &&
              _selectedDate?.month == date.month &&
              _selectedDate?.year == date.year)
          ? null
          : date;
    });
    if (_selectedDate != null && _scrollController.hasClients) {
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

  Future<void> _loadHolidays() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _api.getHolidays(
        _currentMonth.year,
        _currentMonth.month,
      );
      if (mounted) {
        setState(() {
          _holidays = result.holidays;
          _isOfflineCache = result.isFromCache;
          _cacheTimestamp = result.cachedAt;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _resetMonthState() {
    _holidays = null;
    _isOfflineCache = false;
    _cacheTimestamp = null;
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _resetMonthState();
    });
    _loadHolidays();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _resetMonthState();
    });
    _loadHolidays();
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month);
    if (today != _currentMonth) {
      setState(() {
        _currentMonth = today;
        _resetMonthState();
      });
      _loadHolidays();
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
        _resetMonthState();
      });
      _loadHolidays();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final preset = settings.selectedPreset;
    final filteredHolidays = (_holidays ?? [])
        .where((h) => settings.isTypeVisible(h.type))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: preset.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Pengaturan',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo-app.png', height: 30, fit: BoxFit.contain),
            const SizedBox(width: 10),
            const Text(
              'Kalender Indonesia',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Hari Ini',
            onPressed: _goToToday,
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragStart: (d) => _dragStartX = d.globalPosition.dx,
        onHorizontalDragEnd: (d) {
          final dx = d.globalPosition.dx - _dragStartX;
          if (dx < -50) _nextMonth();
          if (dx > 50) _prevMonth();
        },
        child: _buildBody(preset.headerColor, filteredHolidays),
      ),
    );
  }

  Widget _buildBody(Color headerColor, List<Holiday> holidays) {
    final header = _MonthHeader(
      currentMonth: _currentMonth,
      onPrev: _prevMonth,
      onNext: _nextMonth,
      onYearTap: () => _selectYear(context),
      headerColor: headerColor,
    );

    if (_isLoading) {
      return Column(
        children: [
          header,
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Memuat data...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return Column(
        children: [
          header,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat data',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                      onPressed: _loadHolidays,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final size = MediaQuery.of(context).size;
    final isTabletLandscape =
        size.shortestSide >= 600 && size.width > size.height;

    if (isTabletLandscape) {
      return Column(
        children: [
          header,
          if (_isOfflineCache) _OfflineBanner(cachedAt: _cacheTimestamp),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: MonthCalendar(
                      year: _currentMonth.year,
                      month: _currentMonth.month,
                      holidays: holidays,
                      selectedDate: _selectedDate,
                      onDayTap: _onDayTap,
                    ),
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
                    child: EventList(
                      holidays: holidays,
                      selectedDate: _selectedDate,
                    ),
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
          if (_isOfflineCache) _OfflineBanner(cachedAt: _cacheTimestamp),
          MonthCalendar(
            year: _currentMonth.year,
            month: _currentMonth.month,
            holidays: holidays,
            selectedDate: _selectedDate,
            onDayTap: _onDayTap,
          ),
          EventList(
            holidays: holidays,
            selectedDate: _selectedDate,
          ),
          const SizedBox(height: 24),
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

class _MonthHeader extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onYearTap;
  final Color headerColor;

  const _MonthHeader({
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.onYearTap,
    required this.headerColor,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'id').format(currentMonth);
    return Container(
      color: headerColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            onPressed: onPrev,
            splashRadius: 20,
          ),
          GestureDetector(
            onTap: onYearTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
            onPressed: onNext,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
