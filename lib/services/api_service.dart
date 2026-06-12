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

  Future<HolidayResult> getHolidays(int year, int month) async {
    final key = '$year-$month';

    // 1. In-memory cache (same session, no flag needed)
    if (_memCache.containsKey(key)) {
      return HolidayResult(holidays: _memCache[key]!, isFromCache: false);
    }

    // 2. Try network
    try {
      final uri = Uri.parse('$_baseUrl?year=$year&month=$month');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      // Persist to disk and update memory cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cacheKey$key', response.body);
      await prefs.setString(
          '$_timestampKey$key', DateTime.now().toIso8601String());

      final holidays = _parse(response.body);
      _memCache[key] = holidays;
      return HolidayResult(holidays: holidays, isFromCache: false);
    } catch (_) {
      // 3. Fall back to disk cache
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$_cacheKey$key');
      if (cached != null) {
        final tsRaw = prefs.getString('$_timestampKey$key');
        final cachedAt = tsRaw != null ? DateTime.tryParse(tsRaw) : null;
        final holidays = _parse(cached);
        _memCache[key] = holidays;
        return HolidayResult(
            holidays: holidays, isFromCache: true, cachedAt: cachedAt);
      }
      rethrow;
    }
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
