import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/holiday.dart';

class ApiService {
  static const _baseUrl = 'https://cal.weruka.dev/api/holidays';
  final _cache = <String, List<Holiday>>{};

  Future<List<Holiday>> getHolidays(int year, int month) async {
    final key = '$year-$month';
    if (_cache.containsKey(key)) return _cache[key]!;

    final uri = Uri.parse('$_baseUrl?year=$year&month=$month');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Gagal memuat data: ${response.statusCode}');
    }

    final List<dynamic> data = json.decode(response.body);
    final holidays = data
        .map((e) => Holiday.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        final dateCmp = a.date.compareTo(b.date);
        if (dateCmp != 0) return dateCmp;
        return a.type.sortOrder.compareTo(b.type.sortOrder);
      });

    _cache[key] = holidays;
    return holidays;
  }
}
