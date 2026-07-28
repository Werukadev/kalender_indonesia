import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class PreloadProgress {
  final int completed;
  final int total;
  final String currentLabel;

  const PreloadProgress({
    required this.completed,
    required this.total,
    required this.currentLabel,
  });

  double get fraction => total == 0 ? 1.0 : completed / total;
}

class PreloadService {
  static const _preloadYearKey = 'preloadYear';
  static const _skipYearKey = 'preloadSkipYear';
  static const _staleAge = Duration(hours: 20);

  /// Disclosed to the user before downloading (App Store guideline 4.2.3(ii)).
  /// 24 months of holiday JSON measures ~75 KB; rounded up for headroom.
  static const downloadSizeLabel = '±100 KB';

  final ApiService api;

  PreloadService(this.api);

  // Returns true if a full prefetch should be offered (first install or new
  // year). Not offered again within the year the user chose to skip — months
  // are then fetched on demand as the user browses.
  static Future<bool> needsPreload() async {
    final prefs = await SharedPreferences.getInstance();
    final year = DateTime.now().year;
    if ((prefs.getInt(_preloadYearKey) ?? 0) == year) return false;
    if ((prefs.getInt(_skipYearKey) ?? 0) == year) return false;
    return true;
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_preloadYearKey, DateTime.now().year);
  }

  static Future<void> markSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skipYearKey, DateTime.now().year);
  }

  // Prefetch all months for the given years, emitting progress events.
  // Skips months whose cache is fresher than [_staleAge].
  Stream<PreloadProgress> prefetch(List<int> years) async* {
    final tasks = [
      for (final y in years)
        for (int m = 1; m <= 12; m++) (year: y, month: m),
    ];
    final total = tasks.length;
    int done = 0;

    for (final t in tasks) {
      yield PreloadProgress(
        completed: done,
        total: total,
        currentLabel: '${_monthName(t.month)} ${t.year}',
      );
      try {
        final age = await api.getCacheAge(t.year, t.month);
        if (age == null || age >= _staleAge) {
          await api.fetchFresh(t.year, t.month);
        }
      } catch (_) {
        // Network unavailable for this month — skip silently.
      }
      done++;
    }

    yield PreloadProgress(
      completed: total,
      total: total,
      currentLabel: 'Selesai',
    );
  }

  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static String _monthName(int m) => _monthNames[m - 1];
}
