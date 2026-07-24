import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../services/bmkg_service.dart';
import '../widgets/batik.dart';
import '../widgets/cached_image.dart';

/// "Info BMKG": weather forecast at the device's GPS position, active
/// nowcast early warnings, maritime forecast for the nearest waters, and
/// earthquake information — all from BMKG public APIs, each section
/// loading independently and falling back to offline-cached data.
class BmkgScreen extends StatefulWidget {
  const BmkgScreen({super.key});

  @override
  State<BmkgScreen> createState() => _BmkgScreenState();
}

enum _LocStatus { ok, permissionDenied, deniedForever, serviceOff, unavailable }

class _LocResult {
  final Position? position;
  final _LocStatus status;
  const _LocResult(this.position, this.status);
}

class _QuakeData {
  final BmkgQuake? latest;
  final List<BmkgQuake> felt;
  final List<BmkgQuake> major;

  const _QuakeData({
    required this.latest,
    required this.felt,
    required this.major,
  });

  bool get isEmpty => latest == null && felt.isEmpty && major.isEmpty;
}

class _BmkgScreenState extends State<BmkgScreen> {
  late Future<(BmkgWeather?, _LocStatus)> _weatherF;
  late Future<BmkgMarineForecast?> _marineF;
  late Future<List<BmkgWarning>> _warningsF;
  late Future<_QuakeData> _quakesF;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  void _startLoad() {
    final locF = _locate();
    _weatherF = locF.then((r) async {
      if (r.position != null) {
        final weather = await BmkgService.forecastByCoord(
          lat: r.position!.latitude,
          lon: r.position!.longitude,
        );
        if (weather != null) return (weather, _LocStatus.ok);
      }
      // No GPS or fetch failed — the last stored forecast is still useful.
      final cached = await BmkgService.cachedForecast();
      if (cached != null) return (cached, _LocStatus.ok);
      return (
        null,
        r.status == _LocStatus.ok ? _LocStatus.unavailable : r.status,
      );
    });
    _marineF = locF.then((r) {
      if (r.position == null) return BmkgService.cachedMarineForecast();
      return BmkgService.marineForecastNear(
        lat: r.position!.latitude,
        lon: r.position!.longitude,
      );
    });
    _warningsF = BmkgService.nowcastWarnings();
    _quakesF = _loadQuakes();
  }

  Future<_QuakeData> _loadQuakes() async {
    final latestF = BmkgService.latestQuake();
    final feltF = BmkgService.feltQuakes();
    final majorF = BmkgService.majorQuakes();
    return _QuakeData(
      latest: await latestF,
      felt: await feltF,
      major: await majorF,
    );
  }

  Future<_LocResult> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const _LocResult(null, _LocStatus.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const _LocResult(null, _LocStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const _LocResult(null, _LocStatus.permissionDenied);
      }
      // Last known fix is instant and easily accurate enough for weather;
      // only wait on a fresh (low-accuracy) fix when there is none.
      var position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _LocResult(position, _LocStatus.ok);
    } catch (_) {
      return const _LocResult(null, _LocStatus.unavailable);
    }
  }

  Future<void> _refresh() async {
    setState(_startLoad);
    await Future.wait([_weatherF, _marineF, _warningsF, _quakesF]);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BatikAppBar(title: Text('Info BMKG')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            // ── Prakiraan cuaca (GPS) ─────────────────────────────────
            const _SectionHeader(
              icon: Icons.wb_sunny_outlined,
              title: 'Prakiraan Cuaca',
              subtitle: 'Titik terdekat dari lokasi perangkat Anda',
            ),
            FutureBuilder<(BmkgWeather?, _LocStatus)>(
              future: _weatherF,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _LoadingCard(
                    label: 'Mengambil lokasi & prakiraan cuaca...',
                  );
                }
                final (weather, status) =
                    snapshot.data ?? (null, _LocStatus.unavailable);
                if (weather != null) return _WeatherCard(weather: weather);
                return _LocationIssueCard(
                  status: status,
                  onRetry: () => setState(_startLoad),
                );
              },
            ),

            // ── Peringatan dini cuaca ─────────────────────────────────
            const _SectionHeader(
              icon: Icons.campaign_outlined,
              title: 'Peringatan Dini Cuaca',
              subtitle: 'Peringatan cuaca ekstrem aktif (nowcast BMKG)',
            ),
            FutureBuilder<List<BmkgWarning>>(
              future: _warningsF,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _LoadingCard(label: 'Memuat peringatan dini...');
                }
                final warnings = snapshot.data ?? const <BmkgWarning>[];
                if (warnings.isEmpty) {
                  return const _AllClearCard(
                    text:
                        'Tidak ada peringatan dini cuaca yang aktif '
                        'saat ini.',
                  );
                }
                return Column(
                  children: warnings
                      .take(6)
                      .map((w) => _WarningTile(warning: w))
                      .toList(),
                );
              },
            ),

            // ── Cuaca maritim ─────────────────────────────────────────
            const _SectionHeader(
              icon: Icons.waves_outlined,
              title: 'Cuaca Maritim',
              subtitle: 'Perairan terdekat dari lokasi Anda',
            ),
            FutureBuilder<BmkgMarineForecast?>(
              future: _marineF,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _LoadingCard(
                    label: 'Memuat prakiraan perairan...',
                  );
                }
                final marine = snapshot.data;
                if (marine == null) {
                  return _NoteCard(
                    text:
                        'Prakiraan cuaca maritim belum tersedia — '
                        'periksa koneksi internet atau izin lokasi.',
                    colorScheme: colorScheme,
                  );
                }
                return _MarineCard(forecast: marine);
              },
            ),

            // ── Gempa bumi ────────────────────────────────────────────
            FutureBuilder<_QuakeData>(
              future: _quakesF,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _LoadingCard(label: 'Memuat data gempa...');
                }
                final data = snapshot.data;
                if (data == null || data.isEmpty) {
                  return _NoteCard(
                    text:
                        'Data gempa BMKG belum tersedia — periksa '
                        'koneksi internet Anda.',
                    colorScheme: colorScheme,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.latest != null) ...[
                      const _SectionHeader(
                        icon: Icons.crisis_alert,
                        title: 'Gempa Bumi Terbaru',
                        subtitle: 'Kejadian terakhir yang tercatat BMKG',
                      ),
                      _LatestQuakeCard(quake: data.latest!),
                    ],
                    if (data.felt.isNotEmpty) ...[
                      const _SectionHeader(
                        icon: Icons.sensors,
                        title: 'Gempa Dirasakan',
                        subtitle: 'Dilaporkan dirasakan masyarakat (skala MMI)',
                      ),
                      ...data.felt.map((q) => _QuakeTile(quake: q)),
                    ],
                    if (data.major.isNotEmpty) ...[
                      const _SectionHeader(
                        icon: Icons.warning_amber_rounded,
                        title: 'Gempa Magnitudo 5,0+',
                        subtitle: '15 kejadian terkini berkekuatan besar',
                      ),
                      ...data.major.map((q) => _QuakeTile(quake: q)),
                    ],
                  ],
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
              child: Text(
                'Sumber data: Badan Meteorologi, Klimatologi, dan '
                'Geofisika (BMKG) — data.bmkg.go.id, cuaca.bmkg.go.id, '
                'peta-maritim.bmkg.go.id.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────

/// Magnitude → severity color (green → amber → orange → red).
Color _magnitudeColor(double? magnitude) {
  if (magnitude == null) return const Color(0xFF78909C);
  if (magnitude < 4.0) return const Color(0xFF43A047);
  if (magnitude < 5.0) return const Color(0xFFF9A825);
  if (magnitude < 6.0) return const Color(0xFFEF6C00);
  return const Color(0xFFC62828);
}

String _magnitudeLabel(double? magnitude) =>
    magnitude == null ? '—' : magnitude.toStringAsFixed(1).replaceAll('.', ',');

/// BMKG weather description → emoji. Order matters ("cerah berawan"
/// must match before "cerah").
String _weatherEmoji(String desc) {
  final d = desc.toLowerCase();
  if (d.contains('petir')) return '⛈️';
  if (d.contains('hujan lebat')) return '🌧️';
  if (d.contains('hujan')) return '🌦️';
  if (d.contains('kabut') || d.contains('kabur') || d.contains('asap')) {
    return '🌫️';
  }
  if (d.contains('cerah berawan')) return '🌤️';
  if (d.contains('cerah')) return '☀️';
  if (d.contains('berawan')) return '☁️';
  return '🌤️';
}

/// BMKG wave category → severity color.
Color _waveColor(String category) {
  switch (category.toLowerCase()) {
    case 'tenang':
      return const Color(0xFF43A047);
    case 'rendah':
      return const Color(0xFF7CB342);
    case 'sedang':
      return const Color(0xFFF9A825);
    case 'tinggi':
      return const Color(0xFFEF6C00);
    case 'sangat tinggi':
      return const Color(0xFFC62828);
    case 'ekstrem':
      return const Color(0xFF8E24AA);
    case 'sangat ekstrem':
      return const Color(0xFF6A1B9A);
    default:
      return const Color(0xFF78909C);
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
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

class _LoadingCard extends StatelessWidget {
  final String label;

  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String text;
  final ColorScheme colorScheme;

  const _NoteCard({required this.text, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  final String text;

  const _AllClearCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF43A047).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 18,
            color: Color(0xFF2E7D32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Explains why location-based weather is unavailable, with the matching
/// call-to-action (grant permission / open settings / retry).
class _LocationIssueCard extends StatelessWidget {
  final _LocStatus status;
  final VoidCallback onRetry;

  const _LocationIssueCard({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (message, actionLabel, action) = switch (status) {
      _LocStatus.permissionDenied => (
        'Izinkan akses lokasi agar prakiraan cuaca mengikuti posisi '
            'Anda.',
        'Izinkan Lokasi',
        onRetry,
      ),
      _LocStatus.deniedForever => (
        'Akses lokasi ditolak permanen — aktifkan lewat pengaturan '
            'aplikasi.',
        'Buka Pengaturan',
        () => Geolocator.openAppSettings(),
      ),
      _LocStatus.serviceOff => (
        'Layanan lokasi (GPS) perangkat sedang nonaktif.',
        'Aktifkan GPS',
        () => Geolocator.openLocationSettings(),
      ),
      _ => (
        'Prakiraan cuaca tidak dapat dimuat saat ini.',
        'Coba Lagi',
        onRetry,
      ),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: action, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

// ── Cuaca ──────────────────────────────────────────────────────────────

class _WeatherCard extends StatelessWidget {
  final BmkgWeather weather;

  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    // Current condition = the forecast point covering this moment.
    final current = weather.entries.firstWhere(
      (e) =>
          e.time != null &&
          e.time!.isAfter(now.subtract(const Duration(hours: 2))),
      orElse: () => weather.entries.first,
    );
    final upcoming = weather.entries
        .where(
          (e) =>
              e.time != null &&
              current.time != null &&
              e.time!.isAfter(current.time!),
        )
        .take(12)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (weather.locationLabel.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    weather.locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _weatherEmoji(current.desc),
                style: const TextStyle(fontSize: 42),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.temp == null
                        ? '--°C'
                        : '${current.temp!.round()}°C',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    current.desc,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (current.humidity != null)
                _InfoChip(
                  icon: Icons.water_drop_outlined,
                  label: 'Kelembapan ${current.humidity!.round()}%',
                ),
              if (current.windSpeed != null)
                _InfoChip(
                  icon: Icons.air_rounded,
                  label: 'Angin ${current.windSpeed!.round()} km/j',
                ),
            ],
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: upcoming.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final e = upcoming[i];
                  final isTomorrow = e.time!.day != now.day;
                  return SizedBox(
                    width: 58,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          (isTomorrow ? 'Bsk ' : '') +
                              DateFormat('HH:mm').format(e.time!),
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _weatherEmoji(e.desc),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.temp == null ? '--' : '${e.temp!.round()}°',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Peringatan dini ────────────────────────────────────────────────────

class _WarningTile extends StatelessWidget {
  final BmkgWarning warning;

  const _WarningTile({required this.warning});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const orange = Color(0xFFEF6C00);
    final timeLabel = warning.pubDate == null
        ? null
        : DateFormat('d MMM • HH:mm', 'id').format(warning.pubDate!);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: orange.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: orange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                if (timeLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                if (warning.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    warning.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Maritim ────────────────────────────────────────────────────────────

class _MarineCard extends StatelessWidget {
  final BmkgMarineForecast forecast;

  const _MarineCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warnings = forecast.entries
        .map((e) => e.warning)
        .whereType<String>()
        .toSet()
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.sailing_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forecast.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kode ${forecast.code} • Terbit ${forecast.issued}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in forecast.entries) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    e.timeDesc,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _waveColor(e.waveCat).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    e.waveCat.isEmpty ? '—' : e.waveCat,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _waveColor(e.waveCat),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_weatherEmoji(e.weather)} ${e.weather} • '
                        'Gelombang ${e.waveDesc}',
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                      if (e.windFrom != null && e.windMax != null)
                        Text(
                          'Angin ${e.windFrom} → ${e.windTo ?? ''}, '
                          '${e.windMin?.round() ?? '-'}–'
                          '${e.windMax!.round()} knot',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (warnings.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Color(0xFFC62828),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warnings.join('\n'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC62828),
                      ),
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

// ── Gempa ──────────────────────────────────────────────────────────────

/// Hero card for the latest earthquake: big magnitude, location, depth &
/// coordinate chips, tsunami-potential banner, felt report, and shakemap.
class _LatestQuakeCard extends StatelessWidget {
  final BmkgQuake quake;

  const _LatestQuakeCard({required this.quake});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final magColor = _magnitudeColor(quake.magnitude);
    final potensi = quake.potensi;
    // "Tidak berpotensi tsunami" is reassuring; anything else mentioning
    // tsunami is a warning.
    final isTsunamiWarning =
        potensi != null &&
        potensi.toLowerCase().contains('tsunami') &&
        !potensi.toLowerCase().contains('tidak');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: magColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: magColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: magColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: magColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _magnitudeLabel(quake.magnitude),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: magColor,
                      ),
                    ),
                    Text(
                      'Magnitudo',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: magColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quake.wilayah,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${quake.tanggal} • ${quake.jam}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.swap_vert_rounded,
                label: 'Kedalaman ${quake.kedalaman}',
              ),
              _InfoChip(
                icon: Icons.place_outlined,
                label: '${quake.lintang}, ${quake.bujur}',
              ),
            ],
          ),
          if (potensi != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    (isTsunamiWarning
                            ? const Color(0xFFC62828)
                            : const Color(0xFF43A047))
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isTsunamiWarning
                        ? Icons.tsunami_rounded
                        : Icons.verified_outlined,
                    size: 18,
                    color: isTsunamiWarning
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      potensi,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isTsunamiWarning
                            ? const Color(0xFFC62828)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (quake.dirasakan != null) ...[
            const SizedBox(height: 12),
            Text(
              'Dirasakan (Skala MMI)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              quake.dirasakan!,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
          if (quake.shakemapUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedImage(
                url: quake.shakemapUrl!,
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Peta guncangan (shakemap) BMKG',
              style: TextStyle(
                fontSize: 10.5,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact row for the felt / M ≥ 5 lists: magnitude badge, location,
/// time, and the felt report or tsunami note when present.
class _QuakeTile extends StatelessWidget {
  final BmkgQuake quake;

  const _QuakeTile({required this.quake});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final magColor = _magnitudeColor(quake.magnitude);
    final detail = quake.dirasakan ?? quake.potensi;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: magColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _magnitudeLabel(quake.magnitude),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: magColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quake.wilayah,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${quake.tanggal} • ${quake.jam} • '
                  'Kedalaman ${quake.kedalaman}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
