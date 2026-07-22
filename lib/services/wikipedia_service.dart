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

/// Looks up the most relevant Indonesian Wikipedia article for a holiday
/// name and returns its summary — used by the holiday detail page's
/// "Sejarah" section.
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
      final direct = await _buildResult(query);
      if (direct != null) {
        _cache[query] = direct;
        return direct;
      }

      // 2) Try the distinctive core of the name as an exact title:
      // "Hari Dharma Wanita Nasional" → "Dharma Wanita" (exact article),
      // "Hari ASI Sedunia" → "ASI" (redirects to "Air susu ibu").
      final core = _corePhrase(query);
      if (core != null) {
        final coreHit = await _buildResult(core);
        if (coreHit != null) {
          _cache[query] = coreHit;
          return coreHit;
        }
      }

      // 3) Otherwise search, but demand real title overlap.
      final title = await _searchBestTitle(query);
      final result = title == null ? null : await _buildResult(title);
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

  /// Resolves [title] to a result whose extract is, when available, the
  /// article's "Sejarah"/"Latar belakang" section — the part explaining why
  /// the commemoration exists — falling back to the lead summary.
  static Future<WikipediaResult?> _buildResult(String title) async {
    final summary = await _fetchSummary(title);
    if (summary == null) return null;
    final history = await _fetchHistorySection(summary.title);
    if (history == null) return summary;
    return WikipediaResult(
      title: summary.title,
      extract: history,
      pageUrl: summary.pageUrl,
      thumbnailUrl: summary.thumbnailUrl,
    );
  }

  /// Section headings that answer "why was this day established".
  static const _historyHeadings = [
    'sejarah',
    'latar belakang',
    'asal',
    'penetapan',
    'pembentukan',
    'peringatan',
  ];

  /// Fetches the article's plain text and slices out the first top-level
  /// section whose heading looks like a history/background section.
  static Future<String?> _fetchHistorySection(String title) async {
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
    final extract =
        (pages.values.first as Map<String, dynamic>)['extract'] as String?;
    if (extract == null || extract.isEmpty) return null;

    // Top-level sections appear as "== Heading ==" lines in the plain text
    // (subsections use three or more equals and don't match this pattern).
    final headings = RegExp(r'^==\s*([^=\n]+?)\s*==\s*$', multiLine: true)
        .allMatches(extract)
        .toList();
    for (var i = 0; i < headings.length; i++) {
      final heading = headings[i].group(1)!.toLowerCase();
      if (!_historyHeadings.any(heading.contains)) continue;
      final start = headings[i].end;
      final end =
          i + 1 < headings.length ? headings[i + 1].start : extract.length;
      var text = extract.substring(start, end).trim();
      // Turn "=== Subheading ===" lines into plain paragraph labels.
      text = text.replaceAllMapped(
        RegExp(r'^=+\s*(.+?)\s*=+\s*$', multiLine: true),
        (m) => '\n${m[1]}\n',
      );
      text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      if (text.isEmpty) return null;
      return _capLength(text, 1800);
    }
    return null;
  }

  static String _capLength(String text, int max) {
    if (text.length <= max) return text;
    final cut = text.substring(0, max);
    final lastStop = cut.lastIndexOf('. ');
    return '${lastStop > max ~/ 2 ? cut.substring(0, lastStop + 1) : cut} …';
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
