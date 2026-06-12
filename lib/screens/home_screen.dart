import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/holiday.dart';
import '../services/api_service.dart';
import '../widgets/month_calendar.dart';
import '../widgets/event_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  late DateTime _currentMonth;
  List<Holiday>? _holidays;
  bool _isLoading = false;
  String? _error;
  double _dragStartX = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final holidays = await _api.getHolidays(
        _currentMonth.year,
        _currentMonth.month,
      );
      if (mounted) {
        setState(() {
          _holidays = holidays;
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

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _holidays = null;
    });
    _loadHolidays();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _holidays = null;
    });
    _loadHolidays();
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month);
    if (today != _currentMonth) {
      setState(() {
        _currentMonth = today;
        _holidays = null;
      });
      _loadHolidays();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', height: 30, fit: BoxFit.contain),
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
      body: Column(
        children: [
          _MonthHeader(
            currentMonth: _currentMonth,
            onPrev: _prevMonth,
            onNext: _nextMonth,
            primaryColor: primaryColor,
          ),
          Expanded(
            child: GestureDetector(
              onHorizontalDragStart: (d) => _dragStartX = d.globalPosition.dx,
              onHorizontalDragEnd: (d) {
                final dx = d.globalPosition.dx - _dragStartX;
                if (dx < -50) _nextMonth();
                if (dx > 50) _prevMonth();
              },
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Memuat data...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
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
      );
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          MonthCalendar(
            year: _currentMonth.year,
            month: _currentMonth.month,
            holidays: _holidays ?? [],
          ),
          EventList(holidays: _holidays ?? []),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Color primaryColor;

  const _MonthHeader({
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'id').format(currentMonth);
    return Container(
      color: primaryColor.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            onPressed: onPrev,
            splashRadius: 20,
          ),
          Text(
            monthName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
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
