import 'dart:convert';

import 'package:http/http.dart' as http;

class WikipediaResult {
  final String title;
  final String extract;
  final String? pageUrl;
  final String? thumbnailUrl;

  const WikipediaResult({
    required this.title,
    required this.extract,
    this.pageUrl,
    this.thumbnailUrl,
  });
}

/// One row of a Wikipedia search result list.
class WikiSearchItem {
  final String title;
  final String? description;
  final String? thumbnailUrl;

  const WikiSearchItem({
    required this.title,
    this.description,
    this.thumbnailUrl,
  });
}

/// Looks up the most relevant Indonesian Wikipedia article for a holiday
/// name and returns its lead summary — used by the holiday detail page's
/// "Artikel Terkait" section (the history itself comes from the cal API).
///
/// Relevance strategy: try the exact title first (redirects included), then
/// fall back to search — but only accept a search hit whose title actually
/// overlaps the holiday name. An irrelevant article is worse than none.
abstract final class WikipediaService {
  static const _lang = 'id';

  /// Minimum two-way title similarity for a search hit to be trusted.
  static const _minTitleScore = 0.6;

  static final _cache = <String, WikipediaResult?>{};

  static Future<WikipediaResult?> lookup(String holidayName) async {
    // "Hari Masyarakat Adat (Internasional)" → "Hari Masyarakat Adat"
    final query =
        holidayName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    if (query.isEmpty) return null;
    if (_cache.containsKey(query)) return _cache[query];

    try {
      // 1) Exact-title hit (follows redirects) is always trustworthy.
      final direct = await _fetchSummary(query);
      if (direct != null) {
        _cache[query] = direct;
        return direct;
      }

      // 2) Try the distinctive core of the name as an exact title:
      // "Hari Dharma Wanita Nasional" → "Dharma Wanita" (exact article),
      // "Hari ASI Sedunia" → "ASI" (redirects to "Air susu ibu").
      final core = _corePhrase(query);
      if (core != null) {
        final coreHit = await _fetchSummary(core);
        if (coreHit != null) {
          _cache[query] = coreHit;
          return coreHit;
        }
      }

      // 3) Otherwise search, but demand real title overlap.
      final title = await _searchBestTitle(query);
      final result = title == null ? null : await _fetchSummary(title);
      _cache[query] = result;
      return result;
    } catch (_) {
      // Network failure: don't poison the cache — a retry may succeed.
      return null;
    }
  }

  static List<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !_stopwords.contains(w))
      .toList();

  /// Strips the generic framing words from a holiday name, keeping word
  /// order, so the remaining distinctive phrase can be tried as an exact
  /// article title. Returns null when nothing distinctive remains.
  static String? _corePhrase(String query) {
    const generic = {'hari', 'sedunia', 'dunia', 'nasional', 'internasional'};
    final words = query
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !generic.contains(w.toLowerCase()))
        .toList();
    if (words.isEmpty) return null;
    final core = words.join(' ');
    return (core == query || core.length < 3) ? null : core;
  }

  // Words that appear in nearly every holiday/article name carry no
  // distinguishing meaning — counting them made "Hari ASI Sedunia" match
  // "Hari Kelapa Sedunia" (2 of 3 words "matched" while the actual subject
  // differed).
  static const _stopwords = {
    'dan', 'untuk', 'para', 'di', 'ke', 'atas',
    'hari', 'sedunia', 'dunia', 'nasional', 'internasional',
    'peringatan', 'daftar', 'indonesia', 'republik',
  };

  /// Two-way similarity: distinctive words shared by both, divided by the
  /// larger word set. Dividing by the larger side penalizes titles carrying
  /// extra differentiators ("Hari Maritim Nasional Tiongkok" scores 0.5
  /// against "Hari Maritim Nasional", below the acceptance threshold).
  static double _titleScore(String query, String title) {
    final queryWords = _tokens(query);
    final titleWords = _tokens(title).toSet();
    if (queryWords.isEmpty || titleWords.isEmpty) return 0;
    final matched = queryWords.where(titleWords.contains).length;
    final larger =
        queryWords.length > titleWords.length ? queryWords.length : titleWords.length;
    return matched / larger;
  }

  static Future<String?> _searchBestTitle(String query) async {
    final uri = Uri.https('$_lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'srlimit': '5',
      'format': 'json',
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final results =
        (data['query']?['search'] as List<dynamic>?) ?? const [];

    String? bestTitle;
    var bestScore = 0.0;
    for (final r in results) {
      final title = (r as Map<String, dynamic>)['title'] as String?;
      if (title == null) continue;
      final score = _titleScore(query, title);
      // Strictly greater: on ties, keep the earlier (higher-ranked) hit.
      if (score > bestScore) {
        bestScore = score;
        bestTitle = title;
      }
    }
    return bestScore >= _minTitleScore ? bestTitle : null;
  }

  /// Public summary fetch by exact article title (used by the encyclopedia
  /// article page).
  static Future<WikipediaResult?> summaryOf(String title) =>
      _fetchSummary(title);

  /// Searches Indonesian Wikipedia and returns result rows with thumbnails
  /// and short descriptions — powers the encyclopedia topic lists.
  static Future<List<WikiSearchItem>> searchArticles(
    String query, {
    int limit = 25,
  }) async {
    if (query.trim().isEmpty) return const [];
    final uri = Uri.https('$_lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': query,
      'gsrlimit': '$limit',
      'prop': 'pageimages|description',
      'piprop': 'thumbnail',
      'pithumbsize': '160',
      'format': 'json',
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) return const [];
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final pages = data['query']?['pages'] as Map<String, dynamic>?;
    if (pages == null) return const [];

    final entries = pages.values
        .whereType<Map<String, dynamic>>()
        .where((p) => p['title'] != null)
        .toList()
      // generator results come unordered; 'index' holds the search rank.
      ..sort((a, b) =>
          ((a['index'] as int?) ?? 0).compareTo((b['index'] as int?) ?? 0));

    return entries
        .map((p) => WikiSearchItem(
              title: p['title'] as String,
              description: p['description'] as String?,
              thumbnailUrl: p['thumbnail']?['source'] as String?,
            ))
        .toList();
  }

  /// Sections that end the readable part of an article.
  static const _tailHeadings = {
    'referensi',
    'pranala luar',
    'lihat pula',
    'catatan kaki',
    'daftar pustaka',
    'bacaan lanjutan',
    'galeri',
    'rujukan',
  };

  /// Full plain-text body of an article, cut before the references/links
  /// tail sections. Returns null when the article has no text.
  static Future<String?> fetchArticleText(String title) async {
    final uri = Uri.https('$_lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'prop': 'extracts',
      'explaintext': '1',
      'redirects': '1',
      'titles': title,
      'format': 'json',
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final pages = data['query']?['pages'] as Map<String, dynamic>?;
    if (pages == null || pages.isEmpty) return null;
    var text =
        (pages.values.first as Map<String, dynamic>)['extract'] as String?;
    if (text == null || text.trim().isEmpty) return null;

    // Cut everything from the first tail section onward.
    for (final m in RegExp(r'^==\s*([^=\n]+?)\s*==\s*$', multiLine: true)
        .allMatches(text)) {
      if (_tailHeadings.contains(m.group(1)!.toLowerCase().trim())) {
        text = text!.substring(0, m.start);
        break;
      }
    }
    return text!.trim().isEmpty ? null : text.trim();
  }

  static Future<WikipediaResult?> _fetchSummary(String title) async {
    final uri = Uri.https(
      '$_lang.wikipedia.org',
      '/api/rest_v1/page/summary/${title.replaceAll(' ', '_')}',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final data = json.decode(resp.body) as Map<String, dynamic>;
    // Disambiguation pages have no useful summary content.
    if (data['type'] == 'disambiguation') return null;
    final extract = data['extract'] as String?;
    if (extract == null || extract.trim().isEmpty) return null;
    return WikipediaResult(
      title: (data['title'] as String?) ?? title,
      extract: extract.trim(),
      pageUrl: data['content_urls']?['mobile']?['page'] as String? ??
          data['content_urls']?['desktop']?['page'] as String?,
      thumbnailUrl: data['thumbnail']?['source'] as String?,
    );
  }
}
