import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class NewsItem {
  final String title;
  final String link;
  final String? description;
  final String? imageUrl;
  final DateTime? pubDate;
  final String source;

  const NewsItem({
    required this.title,
    required this.link,
    required this.source,
    this.description,
    this.imageUrl,
    this.pubDate,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'source': source,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (pubDate != null) 'pubDate': pubDate!.toIso8601String(),
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        title: json['title'] as String,
        link: json['link'] as String,
        source: json['source'] as String? ?? '',
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        pubDate: json['pubDate'] == null
            ? null
            : DateTime.tryParse(json['pubDate'] as String),
      );
}

/// Aggregates Indonesian news RSS feeds (CNN Indonesia, Tempo, ANTARA) and
/// Google News search — the latter used to pull coverage of today's
/// holidays from the calendar, across many more outlets (Kompas, Detik,
/// etc. appear there even though their own RSS endpoints are defunct).
abstract final class NewsService {
  static const _headers = {'User-Agent': 'Mozilla/5.0'};

  /// Outlets with a working official RSS endpoint (probed 2026-07).
  static const _feeds = [
    ('CNN Indonesia', 'https://www.cnnindonesia.com/nasional/rss'),
    ('Tempo', 'https://rss.tempo.co/nasional'),
    ('ANTARA', 'https://www.antaranews.com/rss/terkini.xml'),
    ('Media Indonesia', 'https://mediaindonesia.com/feed'),
    ('SINDOnews', 'https://nasional.sindonews.com/rss'),
    ('Kumparan', 'https://lapi.kumparan.com/v2.0/rss/'),
    ('Detik', 'https://news.detik.com/rss'),
    ('VOI.id', 'https://voi.id/rss'),
    ('Mongabay Indonesia', 'https://mongabay.co.id/feed'),
    ('BBC Indonesia', 'https://feeds.bbci.co.uk/indonesia/rss.xml'),
    ('Bloomberg Technoz', 'https://www.bloombergtechnoz.com/rss'),
  ];

  /// Outlets whose official RSS is defunct or Cloudflare-walled — served
  /// through Google News per-site search instead, as a stand-in feed.
  static const _gnewsOutlets = [
    ('Kompas.com', 'kompas.com'),
    ('VIVA.co.id', 'viva.co.id'),
    ('JPNN', 'jpnn.com'),
    ('Republika', 'republika.co.id'),
    ('Tirto.id', 'tirto.id'),
    ('CNA Indonesia', 'cna.id'),
    ('DW Indonesia', 'dw.com'),
    ('The Jakarta Post', 'thejakartapost.com'),
  ];

  static String _gnewsSiteUrl(String domain) =>
      'https://news.google.com/rss/search?q=site:$domain&hl=id&gl=ID&ceid=ID:id';

  /// Latest general news, merged from all feeds, newest first,
  /// deduplicated by link.
  static Future<List<NewsItem>> fetchLatest() async {
    final results = await Future.wait([
      ..._feeds.map((f) => _fetchFeed(f.$1, f.$2)),
      ..._gnewsOutlets.map((o) => _fetchFeed(o.$1, _gnewsSiteUrl(o.$2))),
    ]);
    final seen = <String>{};
    final all = results
        .expand((items) => items)
        .where((n) => seen.add(n.link))
        .toList()
      ..sort((a, b) {
        if (a.pubDate == null && b.pubDate == null) return 0;
        if (a.pubDate == null) return 1;
        if (b.pubDate == null) return -1;
        return b.pubDate!.compareTo(a.pubDate!);
      });
    return all;
  }

  /// News about one holiday, via Google News search (Indonesian edition).
  /// Widens coverage well beyond the three fixed feeds.
  static Future<List<NewsItem>> fetchHolidayNews(String holidayName) async {
    final query = Uri.encodeComponent(holidayName);
    final url =
        'https://news.google.com/rss/search?q=$query&hl=id&gl=ID&ceid=ID:id';
    return _fetchFeed('Google News', url);
  }

  static Future<List<NewsItem>> _fetchFeed(String source, String url) async {
    try {
      final resp = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return const [];
      // Cap per feed so no single outlet floods the merged list.
      return _parseRss(utf8.decode(resp.bodyBytes), source)
          .take(20)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<NewsItem> _parseRss(String xmlString, String fallbackSource) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlString);
    } catch (_) {
      return const [];
    }

    return doc.findAllElements('item').map((item) {
      String? text(String name) {
        final value = item.getElement(name)?.innerText.trim();
        return (value == null || value.isEmpty) ? null : value;
      }

      final rawDesc = text('description');
      var image = item.getElement('enclosure')?.getAttribute('url') ??
          _mediaContentUrl(item);
      if (image == null && rawDesc != null) {
        image = RegExp(r'''<img[^>]+src\s*=\s*["']([^"']+)["']''')
            .firstMatch(rawDesc)
            ?.group(1)
            ?.replaceAll('&amp;', '&');
      }

      // Google News puts the real outlet in <source>.
      final outlet = text('source') ?? fallbackSource;

      return NewsItem(
        title: _stripHtml(text('title') ?? ''),
        link: text('link') ?? text('guid') ?? '',
        description: rawDesc == null ? null : _stripHtml(rawDesc),
        imageUrl: image,
        pubDate: _parseRfc822(text('pubDate')),
        source: outlet,
      );
    }).where((n) => n.title.isNotEmpty && n.link.isNotEmpty).toList();
  }

  static String? _mediaContentUrl(XmlElement item) {
    for (final el in item.childElements) {
      if (el.name.local == 'content' &&
          (el.name.prefix == 'media') &&
          el.getAttribute('medium') != 'video') {
        final url = el.getAttribute('url');
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Parses RFC-822 dates as used by RSS
  /// ("Thu, 23 Jul 2026 20:26:20 +0700" / "... GMT"). Returns local time.
  static DateTime? _parseRfc822(String? input) {
    if (input == null) return null;
    final m = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]{1,4})?',
    ).firstMatch(input);
    if (m == null) return null;
    final month = _months[m.group(2)!.toLowerCase()];
    if (month == null) return null;

    var offset = Duration.zero;
    final zone = m.group(7);
    if (zone != null && RegExp(r'^[+-]\d{4}$').hasMatch(zone)) {
      final sign = zone.startsWith('-') ? -1 : 1;
      offset = Duration(
        hours: sign * int.parse(zone.substring(1, 3)),
        minutes: sign * int.parse(zone.substring(3, 5)),
      );
    }
    // Named zones (GMT/UT/UTC) mean zero offset; anything else is treated
    // as UTC too — close enough for display purposes.

    final utc = DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    ).subtract(offset);
    return utc.toLocal();
  }
}
