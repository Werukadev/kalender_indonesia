import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/holiday.dart';

class HolidayResult {
  final List<Holiday> holidays;
  final bool isFromCache;
  final DateTime? cachedAt;

  const HolidayResult({
    required this.holidays,
    required this.isFromCache,
    this.cachedAt,
  });
}

class ApiService {
  static const _baseUrl = 'https://cal.weruka.dev/api/holidays';
  static const _cacheKey = 'holidays_cache_';
  static const _timestampKey = 'holidays_ts_';

  final _memCache = <String, List<Holiday>>{};

  // Returns cached data (memory → disk) instantly. Returns null if no cache.
  Future<HolidayResult?> getCached(int year, int month) async {
    final key = '$year-$month';
    if (_memCache.containsKey(key)) {
      return HolidayResult(holidays: _memCache[key]!, isFromCache: false);
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cacheKey$key');
    if (raw == null) return null;
    final tsRaw = prefs.getString('$_timestampKey$key');
    final holidays = _parse(raw);
    _memCache[key] = holidays;
    return HolidayResult(
      holidays: holidays,
      isFromCache: true,
      cachedAt: tsRaw != null ? DateTime.tryParse(tsRaw) : null,
    );
  }

  // Fetches fresh data from network and updates cache. Throws on failure.
  Future<HolidayResult> fetchFresh(int year, int month) async {
    final key = '$year-$month';
    final uri = Uri.parse('$_baseUrl?year=$year&month=$month');
    final response =
        await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cacheKey$key', response.body);
    await prefs.setString(
        '$_timestampKey$key', DateTime.now().toIso8601String());

    final holidays = _parse(response.body);
    _memCache[key] = holidays;
    return HolidayResult(holidays: holidays, isFromCache: false);
  }

  // Returns how old the disk cache is, null if no cache exists.
  Future<Duration?> getCacheAge(int year, int month) async {
    final key = '$year-$month';
    final prefs = await SharedPreferences.getInstance();
    final tsRaw = prefs.getString('$_timestampKey$key');
    if (tsRaw == null) return null;
    final ts = DateTime.tryParse(tsRaw);
    if (ts == null) return null;
    return DateTime.now().difference(ts);
  }

  List<Holiday> _parse(String body) {
    final List<dynamic> data = json.decode(body);
    return (data
        .map((e) => Holiday.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        if (d != 0) return d;
        return a.type.sortOrder.compareTo(b.type.sortOrder);
      }));
  }
}
