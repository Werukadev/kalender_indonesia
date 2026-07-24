import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'news_service.dart';
import 'offline_cache.dart';

/// One earthquake entry from BMKG's public TEWS feeds.
class BmkgQuake {
  final String tanggal; // "23 Jul 2026"
  final String jam; // "12:34:56 WIB"
  final DateTime? dateTime;
  final double? magnitude;
  final String kedalaman;
  final String wilayah;
  final String lintang;
  final String bujur;

  /// Tsunami potential statement — only present on the M ≥ 5 feeds.
  final String? potensi;

  /// MMI felt-intensity report ("III Bantul, II-III Sleman, ...").
  final String? dirasakan;

  /// Full URL of the shakemap image, when the feed provides one.
  final String? shakemapUrl;

  const BmkgQuake({
    required this.tanggal,
    required this.jam,
    required this.kedalaman,
    required this.wilayah,
    required this.lintang,
    required this.bujur,
    this.dateTime,
    this.magnitude,
    this.potensi,
    this.dirasakan,
    this.shakemapUrl,
  });

  factory BmkgQuake.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] as String?)?.trim() ?? '';
    String? maybe(String key) {
      final v = (json[key] as String?)?.trim();
      return (v == null || v.isEmpty || v == '-') ? null : v;
    }

    final shakemap = maybe('Shakemap');
    return BmkgQuake(
      tanggal: text('Tanggal'),
      jam: text('Jam'),
      dateTime: DateTime.tryParse(text('DateTime'))?.toLocal(),
      magnitude: double.tryParse(text('Magnitude')),
      kedalaman: text('Kedalaman'),
      wilayah: text('Wilayah'),
      lintang: text('Lintang'),
      bujur: text('Bujur'),
      potensi: maybe('Potensi'),
      dirasakan: maybe('Dirasakan'),
      shakemapUrl: shakemap == null
          ? null
          : '${BmkgService._quakeBase}/$shakemap',
    );
  }
}

/// One 3-hourly forecast point from BMKG's digital forecast.
class BmkgWeatherEntry {
  final DateTime? time; // device-local
  final double? temp; // °C
  final double? humidity; // %
  final double? windSpeed; // km/h
  final String desc;

  const BmkgWeatherEntry({
    required this.desc,
    this.time,
    this.temp,
    this.humidity,
    this.windSpeed,
  });

  factory BmkgWeatherEntry.fromJson(Map<String, dynamic> json) {
    double? number(String key) => (json[key] as num?)?.toDouble();
    return BmkgWeatherEntry(
      time: DateTime.tryParse((json['datetime'] as String?) ?? '')?.toLocal(),
      temp: number('t'),
      humidity: number('hu'),
      windSpeed: number('ws'),
      desc: (json['weather_desc'] as String?)?.trim() ?? '',
    );
  }
}

/// Location-resolved forecast (3 days, 3-hourly) for one point.
class BmkgWeather {
  final String? provinsi;
  final String? kotkab;
  final String? kecamatan;
  final String? desa;
  final List<BmkgWeatherEntry> entries; // chronological

  const BmkgWeather({
    required this.entries,
    this.provinsi,
    this.kotkab,
    this.kecamatan,
    this.desa,
  });

  String get locationLabel {
    final parts = [
      desa,
      kecamatan,
      kotkab,
    ].where((p) => p != null && p.isNotEmpty).cast<String>().toList();
    return parts.isEmpty ? (provinsi ?? '') : parts.join(', ');
  }
}

/// One active nowcast (peringatan dini cuaca) warning from BMKG's CAP RSS.
class BmkgWarning {
  final String title;
  final String description;
  final String link;
  final DateTime? pubDate;

  const BmkgWarning({
    required this.title,
    required this.description,
    required this.link,
    this.pubDate,
  });
}

/// A maritime forecast area (perairan) with its polygon centroid — used to
/// find the waters nearest to the device.
class BmkgMarineArea {
  final String code; // "U.04"
  final String name; // "Samudera Hindia selatan Banten"
  final double lat;
  final double lon;

  const BmkgMarineArea({
    required this.code,
    required this.name,
    required this.lat,
    required this.lon,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'lat': lat,
    'lon': lon,
  };

  factory BmkgMarineArea.fromJson(Map<String, dynamic> json) => BmkgMarineArea(
    code: json['code'] as String,
    name: json['name'] as String,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
  );
}

/// One forecast period ("Hari ini", "Besok", ...) for a maritime area.
class BmkgMarineEntry {
  final String timeDesc;
  final String weather;
  final String waveCat; // Tenang / Rendah / Sedang / Tinggi / ...
  final String waveDesc; // "1.25 - 2.5 m"
  final String? warning;
  final String? windFrom;
  final String? windTo;
  final double? windMin;
  final double? windMax;

  const BmkgMarineEntry({
    required this.timeDesc,
    required this.weather,
    required this.waveCat,
    required this.waveDesc,
    this.warning,
    this.windFrom,
    this.windTo,
    this.windMin,
    this.windMax,
  });

  factory BmkgMarineEntry.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] as String?)?.trim() ?? '';
    String? maybe(String key) {
      final v = (json[key] as String?)?.trim();
      return (v == null || v.isEmpty || v == '-') ? null : v;
    }

    double? number(String key) => (json[key] as num?)?.toDouble();
    return BmkgMarineEntry(
      timeDesc: text('time_desc'),
      weather: maybe('weather') ?? text('weather_desc'),
      waveCat: text('wave_cat'),
      waveDesc: text('wave_desc'),
      warning: maybe('warning_desc'),
      windFrom: maybe('wind_from'),
      windTo: maybe('wind_to'),
      windMin: number('wind_speed_min'),
      windMax: number('wind_speed_max'),
    );
  }
}

class BmkgMarineForecast {
  final String code;
  final String name;
  final String issued;
  final List<BmkgMarineEntry> entries;

  const BmkgMarineForecast({
    required this.code,
    required this.name,
    required this.issued,
    required this.entries,
  });
}

/// BMKG public data feeds (no API key needed):
///  - earthquakes (data.bmkg.go.id TEWS),
///  - digital weather forecast by coordinate (cuaca.bmkg.go.id — the same
///    API the official website uses),
///  - nowcast early warnings (CAP RSS at bmkg.go.id/alerts),
///  - maritime forecasts (peta-maritim.bmkg.go.id public_api).
/// Successful responses are stored via [OfflineCache], so the page keeps
/// showing the last known data when offline.
abstract final class BmkgService {
  static const _quakeBase = 'https://data.bmkg.go.id/DataMKG/TEWS';
  static const _marineBase = 'https://peta-maritim.bmkg.go.id/public_api';
  // No custom User-Agent here: data.bmkg.go.id's CDN rejects a bare
  // "Mozilla/5.0" with 403, while Dart's default UA passes on every
  // BMKG host (verified 2026-07). Don't "fix" this by adding one back.
  static const _ns = 'bmkg';

  // ── Gempa ────────────────────────────────────────────────────────────

  /// Latest earthquake (any magnitude), including shakemap + felt report.
  static Future<BmkgQuake?> latestQuake() async {
    final data = await _getJson('$_quakeBase/autogempa.json', 'autogempa');
    final gempa = data?['Infogempa']?['gempa'];
    return gempa is Map<String, dynamic> ? BmkgQuake.fromJson(gempa) : null;
  }

  /// Recently felt earthquakes (with MMI reports).
  static Future<List<BmkgQuake>> feltQuakes() => _quakeList('gempadirasakan');

  /// Recent M ≥ 5.0 earthquakes (with tsunami-potential statements).
  static Future<List<BmkgQuake>> majorQuakes() => _quakeList('gempaterkini');

  static Future<List<BmkgQuake>> _quakeList(String name) async {
    final data = await _getJson('$_quakeBase/$name.json', name);
    final list = data?['Infogempa']?['gempa'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BmkgQuake.fromJson)
        .toList();
  }

  // ── Prakiraan cuaca (by GPS coordinate) ──────────────────────────────

  /// 3-day, 3-hourly forecast for the point nearest to [lat]/[lon].
  static Future<BmkgWeather?> forecastByCoord({
    required double lat,
    required double lon,
  }) async {
    final data = await _getJson(
      'https://cuaca.bmkg.go.id/api/df/v1/forecast/coord?lon=$lon&lat=$lat',
      'forecast_coord',
    );
    return data == null ? null : _parseWeather(data);
  }

  /// Last successfully fetched forecast — for offline / no-GPS fallback.
  static Future<BmkgWeather?> cachedForecast() async {
    final cached = await OfflineCache.getJson(_ns, 'forecast_coord');
    return cached is Map<String, dynamic> ? _parseWeather(cached) : null;
  }

  static BmkgWeather? _parseWeather(Map<String, dynamic> data) {
    var lokasi = data['lokasi'];
    final entries = <BmkgWeatherEntry>[];
    final dataList = data['data'];
    if (dataList is List) {
      for (final d in dataList) {
        if (d is! Map<String, dynamic>) continue;
        lokasi = (lokasi is Map<String, dynamic>) ? lokasi : d['lokasi'];
        final cuaca = d['cuaca'];
        if (cuaca is! List) continue;
        // `cuaca` is an array of days, each an array of 3-hourly points —
        // but accept a flat list too, in case the shape ever changes.
        for (final day in cuaca) {
          if (day is List) {
            entries.addAll(
              day.whereType<Map<String, dynamic>>().map(
                BmkgWeatherEntry.fromJson,
              ),
            );
          } else if (day is Map<String, dynamic>) {
            entries.add(BmkgWeatherEntry.fromJson(day));
          }
        }
      }
    }
    if (entries.isEmpty) return null;
    entries.sort((a, b) {
      if (a.time == null || b.time == null) return 0;
      return a.time!.compareTo(b.time!);
    });
    final lok = lokasi is Map<String, dynamic> ? lokasi : null;
    String? field(String key) {
      final v = (lok?[key] as String?)?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    return BmkgWeather(
      entries: entries,
      provinsi: field('provinsi'),
      kotkab: field('kotkab'),
      kecamatan: field('kecamatan'),
      desa: field('desa'),
    );
  }

  // ── Peringatan dini cuaca (nowcast CAP RSS) ──────────────────────────

  /// Active nowcast warnings, newest first.
  static Future<List<BmkgWarning>> nowcastWarnings() async {
    const key = 'nowcast_rss';
    try {
      final resp = await http
          .get(Uri.parse('https://www.bmkg.go.id/alerts/nowcast/id'))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return _cachedWarnings();
      final xmlString = utf8.decode(resp.bodyBytes, allowMalformed: true);
      final warnings = _parseWarnings(xmlString);
      OfflineCache.putJson(_ns, key, xmlString);
      return warnings;
    } catch (_) {
      return _cachedWarnings();
    }
  }

  static Future<List<BmkgWarning>> _cachedWarnings() async {
    final cached = await OfflineCache.getJson(_ns, 'nowcast_rss');
    return cached is String ? _parseWarnings(cached) : const [];
  }

  static List<BmkgWarning> _parseWarnings(String xmlString) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlString);
    } catch (_) {
      return const [];
    }
    return doc
        .findAllElements('item')
        .map((item) {
          String text(String name) =>
              item.getElement(name)?.innerText.trim() ?? '';
          return BmkgWarning(
            title: text('title'),
            description: text('description'),
            link: text('link'),
            pubDate: NewsService.parseRfc822(text('pubDate')),
          );
        })
        .where((w) => w.title.isNotEmpty)
        .toList();
  }

  // ── Cuaca maritim ────────────────────────────────────────────────────

  /// Forecast for the maritime area (perairan) nearest to [lat]/[lon].
  static Future<BmkgMarineForecast?> marineForecastNear({
    required double lat,
    required double lon,
  }) async {
    final areas = await _marineAreas();
    if (areas.isEmpty) return cachedMarineForecast();

    BmkgMarineArea? nearest;
    var best = double.infinity;
    for (final a in areas) {
      final dLat = a.lat - lat;
      final dLon = a.lon - lon;
      final d = dLat * dLat + dLon * dLon;
      if (d < best) {
        best = d;
        nearest = a;
      }
    }
    if (nearest == null) return cachedMarineForecast();

    final data = await _getJson(
      '$_marineBase/perairan/${nearest.code}.json',
      'marine_forecast',
    );
    return data == null ? cachedMarineForecast() : _parseMarine(data);
  }

  /// Last successfully fetched maritime forecast (offline fallback).
  static Future<BmkgMarineForecast?> cachedMarineForecast() async {
    final cached = await OfflineCache.getJson(_ns, 'marine_forecast');
    return cached is Map<String, dynamic> ? _parseMarine(cached) : null;
  }

  static BmkgMarineForecast? _parseMarine(Map<String, dynamic> data) {
    final list = data['data'];
    final entries = list is List
        ? list
              .whereType<Map<String, dynamic>>()
              .map(BmkgMarineEntry.fromJson)
              .toList()
        : <BmkgMarineEntry>[];
    if (entries.isEmpty) return null;
    return BmkgMarineForecast(
      code: (data['code'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      issued: (data['issued'] as String?) ?? '',
      entries: entries,
    );
  }

  /// Maritime areas with centroids, derived once from BMKG's region
  /// GeoJSON (~700 KB) and cached compactly (~150 rows) after that.
  static Future<List<BmkgMarineArea>> _marineAreas() async {
    const key = 'marine_areas';
    final cached = await OfflineCache.getJson(_ns, key);
    if (cached is List && cached.isNotEmpty) {
      return cached
          .whereType<Map<String, dynamic>>()
          .map(BmkgMarineArea.fromJson)
          .toList();
    }
    try {
      final resp = await http
          .get(Uri.parse('$_marineBase/static/wilayah_perairan.json'))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return const [];
      final geo =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final features = geo['features'];
      if (features is! List) return const [];

      final areas = <BmkgMarineArea>[];
      for (final f in features) {
        if (f is! Map<String, dynamic>) continue;
        final props = f['properties'];
        final code = props is Map<String, dynamic>
            ? (props['WP_1'] as String?)?.trim()
            : null;
        final name = props is Map<String, dynamic>
            ? (props['WP_IMM'] as String?)?.trim()
            : null;
        final centroid = _polygonCentroid(f['geometry']);
        if (code == null || code.isEmpty || name == null || centroid == null) {
          continue;
        }
        areas.add(
          BmkgMarineArea(
            code: code,
            name: name,
            lat: centroid.$1,
            lon: centroid.$2,
          ),
        );
      }
      if (areas.isNotEmpty) {
        OfflineCache.putJson(_ns, key, areas.map((a) => a.toJson()).toList());
      }
      return areas;
    } catch (_) {
      return const [];
    }
  }

  /// Average of the outer-ring vertices — not an exact centroid, but more
  /// than good enough to pick the nearest forecast area.
  static (double, double)? _polygonCentroid(Object? geometry) {
    if (geometry is! Map<String, dynamic>) return null;
    final coords = geometry['coordinates'];
    // Polygon: [ring][point][lon,lat]; MultiPolygon adds one more level.
    List? outerRing;
    if (geometry['type'] == 'Polygon' && coords is List && coords.isNotEmpty) {
      outerRing = coords.first as List?;
    } else if (geometry['type'] == 'MultiPolygon' &&
        coords is List &&
        coords.isNotEmpty) {
      final firstPolygon = coords.first;
      if (firstPolygon is List && firstPolygon.isNotEmpty) {
        outerRing = firstPolygon.first as List?;
      }
    }
    if (outerRing == null || outerRing.isEmpty) return null;

    var latSum = 0.0, lonSum = 0.0, count = 0;
    for (final p in outerRing) {
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
        lonSum += (p[0] as num).toDouble();
        latSum += (p[1] as num).toDouble();
        count++;
      }
    }
    return count == 0 ? null : (latSum / count, lonSum / count);
  }

  // ── Shared fetch helper ──────────────────────────────────────────────

  /// GET + decode JSON with an [OfflineCache] fallback under [cacheKey].
  static Future<Map<String, dynamic>?> _getJson(
    String url,
    String cacheKey,
  ) async {
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return _cachedJson(cacheKey);
      final data =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      OfflineCache.putJson(_ns, cacheKey, data);
      return data;
    } catch (_) {
      return _cachedJson(cacheKey);
    }
  }

  static Future<Map<String, dynamic>?> _cachedJson(String cacheKey) async {
    final cached = await OfflineCache.getJson(_ns, cacheKey);
    return cached is Map<String, dynamic> ? cached : null;
  }
}
