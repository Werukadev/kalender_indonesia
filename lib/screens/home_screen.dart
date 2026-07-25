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
import '../services/notification_service.dart';
import '../widgets/batik.dart';
import '../widgets/month_calendar.dart';
import '../widgets/event_list.dart';
import 'about_screen.dart';
import 'bmkg_screen.dart';
import 'encyclopedia_screen.dart';
import 'galeri_screen.dart';
import 'jelajah_hari_screen.dart';
import 'news_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  List<Holiday>? _holidays;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  bool _isOfflineCache = false;
  DateTime? _cacheTimestamp;
  double _calendarDragStartX = 0;
  double _listDragStartX = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadHolidays();
    _loadDeviceEvents();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncNotifications());
  }

  /// Once per app open: (re)schedules the midnight holiday notifications for
  /// the current + next month. Fire-and-forget — failures just mean the
  /// schedule from the previous run stays in place.
  Future<void> _syncNotifications() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.notificationsEnabled) return;
    final granted = await NotificationService.requestPermission();
    if (!granted) return;
    NotificationService.resync(
      _api,
      enabled: true,
      visibleTypes: settings.visibleTypes,
    );
    // BMKG alerts (new significant quake / weather warning) — also
    // fire-and-forget, deduplicated inside.
    NotificationService.checkBmkgAlerts();
  }

  void _loadDeviceEvents() {
    context.read<DeviceCalendarProvider>().loadMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onDayTap(DateTime date) {
    // Gray outside dates belong to the previous/next month — jump there.
    final monthChanged =
        date.year != _currentMonth.year || date.month != _currentMonth.month;
    setState(() {
      _selectedDate = date;
      if (monthChanged) {
        _currentMonth = DateTime(date.year, date.month);
        _resetMonthState();
      }
    });
    if (monthChanged) {
      _loadHolidays();
      _loadDeviceEvents();
    }
    // Snap the agenda list back to the top for the newly selected day.
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
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
    final cached = await _api.getCached(
      _currentMonth.year,
      _currentMonth.month,
    );
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
      final fresh = await _api.fetchFresh(
        _currentMonth.year,
        _currentMonth.month,
      );
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

  /// Moves the selected day by [delta] days, crossing into the next/previous
  /// month (and reloading its data) when the shift lands outside the month
  /// currently on screen.
  void _shiftSelectedDay(int delta) {
    final newDate = _selectedDate.add(Duration(days: delta));
    final monthChanged =
        newDate.year != _currentMonth.year ||
        newDate.month != _currentMonth.month;
    setState(() {
      _selectedDate = newDate;
      if (monthChanged) {
        _currentMonth = DateTime(newDate.year, newDate.month);
        _resetMonthState();
      }
    });
    if (monthChanged) {
      _loadHolidays();
      _loadDeviceEvents();
    }
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
    final preset = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).selectedPreset;
    final primaryColor = preset.primaryColor;
    final currentYear = _currentMonth.year;
    const firstYear = 2010;
    final lastYear = DateTime.now().year + 5;

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
    final deviceEvents = deviceCalendar.eventsFor(
      _currentMonth.year,
      _currentMonth.month,
    );
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
        key: _scaffoldKey,
        drawer: _AppDrawer(headerColor: preset.primaryColor),
        body: _buildBody(
          preset.primaryColor,
          filteredHolidays,
          deviceEvents,
          calendarPermissionDenied,
        ),
      ),
    );
  }

  Widget _withCalendarSwipe(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) => _calendarDragStartX = d.globalPosition.dx,
      onHorizontalDragEnd: (d) {
        final dx = d.globalPosition.dx - _calendarDragStartX;
        if (dx < -50) _nextMonth();
        if (dx > 50) _prevMonth();
      },
      child: child,
    );
  }

  Widget _withListSwipe(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) => _listDragStartX = d.globalPosition.dx,
      onHorizontalDragEnd: (d) {
        final dx = d.globalPosition.dx - _listDragStartX;
        if (dx < -50) _shiftSelectedDay(1);
        if (dx > 50) _shiftSelectedDay(-1);
      },
      child: child,
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
      onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      onTodayTap: _goToToday,
      onYearTap: () => _selectYear(context),
      headerColor: headerColor,
      isRefreshing: _isRefreshing,
    );

    final calendar = _withCalendarSwipe(
      MonthCalendar(
        year: _currentMonth.year,
        month: _currentMonth.month,
        holidays: holidays,
        deviceEvents: deviceEvents,
        selectedDate: _selectedDate,
        onDayTap: _onDayTap,
      ),
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
            onRefresh: () => context.read<DeviceCalendarProvider>().refresh(
              _currentMonth.year,
              _currentMonth.month,
            ),
          )
        : null;

    final divider = Divider(
      height: 1,
      thickness: 0.5,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
    );

    if (isTabletLandscape) {
      return Column(
        children: [
          header,
          ?permissionBanner,
          if (_isOfflineCache) _OfflineBanner(cachedAt: _cacheTimestamp),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 5, child: calendar),
                VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.12),
                ),
                Expanded(
                  flex: 4,
                  child: _withListSwipe(
                    SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 24),
                      child: holidaySection,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Samsung-Calendar-like layout: the month grid fills the upper part of
    // the screen, the selected day's agenda sits below a thin divider.
    return Column(
      children: [
        header,
        ?permissionBanner,
        if (_isOfflineCache) _OfflineBanner(cachedAt: _cacheTimestamp),
        Expanded(flex: 11, child: calendar),
        divider,
        Expanded(
          flex: 9,
          child: _withListSwipe(
            SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              child: holidaySection,
            ),
          ),
        ),
      ],
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
          const Icon(
            Icons.wifi_off_rounded,
            size: 13,
            color: Color(0xFFF59E0B),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
  final VoidCallback onMenuTap;
  final VoidCallback onTodayTap;
  final VoidCallback onYearTap;
  final Color headerColor;
  final bool isRefreshing;

  const _MonthHeader({
    required this.currentMonth,
    required this.onMenuTap,
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
      // The kawung painter intentionally overdraws past its bounds; clip
      // so it can't bleed onto the calendar below (visible on Midnight).
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: batikGradient(headerColor),
        border: Border(bottom: batikEdgeSide),
      ),
      child: CustomPaint(
        painter: const BatikKawungPainter(spacing: 40, intensity: 0.7),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  tooltip: 'Menu',
                  onPressed: onMenuTap,
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white60,
                        ),
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
      ),
    );
  }
}

// ── App Drawer ────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final Color headerColor;

  const _AppDrawer({required this.headerColor});

  void _openPage(BuildContext context, Widget page) {
    Navigator.pop(context); // close the drawer first
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Fixed header height regardless of theme/text metrics — only the
    // colors may change when the theme does.
    final headerHeight = MediaQuery.of(context).padding.top + 132.0;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
        child: Container(
          // Fully opaque: any translucency here lets the batik-patterned
          // calendar header behind the drawer bleed through, which is
          // glaring on near-black themes (Midnight).
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: headerHeight,
                // Clip the painter's intentional overdraw — otherwise the
                // motif bleeds onto the drawer body, glaring on Midnight.
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  gradient: batikGradient(headerColor),
                  border: Border(bottom: batikEdgeSide),
                ),
                child: CustomPaint(
                  painter: const BatikKawungPainter(),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "Kalender" in Javanese script (aksara Jawa).
                          const Text(
                            'ꦏꦭꦺꦤ꧀ꦢꦺꦂ',
                            style: TextStyle(
                              fontFamily: 'NotoSansJavanese',
                              color: Colors.white,
                              fontSize: 34,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'KALENDER INDONESIA',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Scrollable main menu area.
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 8),
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.auto_stories_outlined,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Jelajah Hari'),
                      subtitle: const Text(
                        'Jelajahi semua hari penting',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      onTap: () =>
                          _openPage(context, const JelajahHariScreen()),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.newspaper_outlined,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Berita Hari Ini'),
                      subtitle: const Text(
                        'Berita terkini & hari penting hari ini',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      onTap: () => _openPage(context, const NewsScreen()),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.menu_book_outlined,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Ensiklopedia Indonesia'),
                      subtitle: const Text(
                        'Budaya, sejarah, geografi & lainnya',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      onTap: () =>
                          _openPage(context, const EncyclopediaScreen()),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.crisis_alert,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Info BMKG'),
                      subtitle: const Text(
                        'Gempa terbaru, dirasakan & magnitudo 5+',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      onTap: () => _openPage(context, const BmkgScreen()),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.photo_library_outlined,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Galeri Nusantara'),
                      subtitle: const Text(
                        'Foto & video Indonesia yang selalu baru',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      onTap: () => _openPage(context, const GaleriScreen()),
                    ),
                  ],
                ),
              ),
              // Sticky bottom section: Pengaturan & Tentang.
              Divider(
                height: 1,
                thickness: 0.5,
                color: colorScheme.onSurface.withValues(alpha: 0.12),
              ),
              SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.settings_outlined,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Pengaturan'),
                      onTap: () => _openPage(context, const SettingsScreen()),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Tentang'),
                      onTap: () => _openPage(context, const AboutScreen()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
