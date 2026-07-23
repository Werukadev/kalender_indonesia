import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'news_service.dart';

/// Persists every fetched news item on the device (app-support dir), so
/// the news list keeps working offline and articles already seen are never
/// lost between sessions.
abstract final class NewsStorage {
  static const _fileName = 'news_history.json';

  /// Keep the history bounded so the file stays small.
  static const _maxItems = 500;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<NewsItem>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final raw = json.decode(await file.readAsString());
      return (raw as List<dynamic>)
          .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Merges [fresh] into the stored history (newest first, deduplicated by
  /// link, capped) and writes it back. Returns the merged list.
  static Future<List<NewsItem>> merge(List<NewsItem> fresh) async {
    final stored = await load();
    final byLink = <String, NewsItem>{};
    for (final item in fresh) {
      byLink[item.link] = item;
    }
    for (final item in stored) {
      byLink.putIfAbsent(item.link, () => item);
    }
    final merged = byLink.values.toList()
      ..sort((a, b) {
        if (a.pubDate == null && b.pubDate == null) return 0;
        if (a.pubDate == null) return 1;
        if (b.pubDate == null) return -1;
        return b.pubDate!.compareTo(a.pubDate!);
      });
    final capped = merged.take(_maxItems).toList();
    try {
      final file = await _file();
      await file
          .writeAsString(json.encode(capped.map((e) => e.toJson()).toList()));
    } catch (_) {
      // Persisting is best-effort; the in-memory list is still returned.
    }
    return capped;
  }
}
