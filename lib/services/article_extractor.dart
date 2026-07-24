import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'offline_cache.dart';

class ExtractedArticle {
  final String? title;
  final String? imageUrl;
  final List<String> paragraphs;

  /// The article's real URL after following redirects (Google News links
  /// point at an interstitial first).
  final String resolvedUrl;

  const ExtractedArticle({
    required this.paragraphs,
    required this.resolvedUrl,
    this.title,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'resolvedUrl': resolvedUrl,
        'paragraphs': paragraphs,
        if (title != null) 'title': title,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  factory ExtractedArticle.fromJson(Map<String, dynamic> json) =>
      ExtractedArticle(
        paragraphs: (json['paragraphs'] as List<dynamic>).cast<String>(),
        resolvedUrl: json['resolvedUrl'] as String,
        title: json['title'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );
}

/// Fetches a news page and pulls out its readable content — a small
/// "reader mode": og-meta for title/image, then the densest cluster of
/// `<p>` tags as the body text.
abstract final class ArticleExtractor {
  static const _headers = {'User-Agent': 'Mozilla/5.0'};

  /// Boilerplate lines that must not appear as article paragraphs.
  static final _junk = RegExp(
    r'baca juga|advertisement|scroll to continue|pilihan editor|'
    r'simak berita|lihat juga|copyright|hak cipta|all rights reserved',
    caseSensitive: false,
  );

  static const _cacheNs = 'news_articles';

  /// Extracts the article, preferring a fresh fetch. Every successful
  /// extraction is stored via [OfflineCache], so an article read once
  /// stays readable offline (or when the source site later breaks).
  static Future<ExtractedArticle?> extract(String url) async {
    final fresh = await _extractFresh(url);
    if (fresh != null) {
      OfflineCache.putJson(_cacheNs, url, fresh.toJson());
      return fresh;
    }
    final cached = await OfflineCache.getJson(_cacheNs, url);
    if (cached is Map<String, dynamic>) {
      try {
        return ExtractedArticle.fromJson(cached);
      } catch (_) {}
    }
    return null;
  }

  static Future<ExtractedArticle?> _extractFresh(String url) async {
    try {
      var resp = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));
      var finalUrl = resp.request?.url.toString() ?? url;

      // Google News serves an interstitial instead of redirecting; the
      // outlet's real link is the first external anchor on that page.
      if (Uri.parse(finalUrl).host.endsWith('news.google.com')) {
        final doc = html_parser.parse(_decode(resp));
        final target = doc
            .querySelectorAll('a[href]')
            .map((a) => a.attributes['href'] ?? '')
            .firstWhere(
              (href) =>
                  href.startsWith('http') &&
                  !Uri.parse(href).host.endsWith('news.google.com') &&
                  !Uri.parse(href).host.endsWith('google.com'),
              orElse: () => '',
            );
        if (target.isEmpty) return null;
        resp = await http
            .get(Uri.parse(target), headers: _headers)
            .timeout(const Duration(seconds: 15));
        finalUrl = resp.request?.url.toString() ?? target;
      }

      if (resp.statusCode != 200) return null;
      final doc = html_parser.parse(_decode(resp));

      String? meta(String property) =>
          doc
              .querySelector('meta[property="$property"]')
              ?.attributes['content'] ??
          doc.querySelector('meta[name="$property"]')?.attributes['content'];

      final paragraphs = _extractParagraphs(doc);
      // A thin body (a teaser sentence or two) reads as a broken article —
      // treat it as a failed extraction so callers fall back to the source
      // link instead of presenting it as the story.
      final bodyLength =
          paragraphs.fold<int>(0, (sum, p) => sum + p.length);
      if (paragraphs.length < 2 || bodyLength < 400) return null;

      return ExtractedArticle(
        title: meta('og:title') ?? doc.querySelector('h1')?.text.trim(),
        imageUrl: meta('og:image'),
        paragraphs: paragraphs,
        resolvedUrl: finalUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static String _decode(http.Response resp) =>
      utf8.decode(resp.bodyBytes, allowMalformed: true);

  /// Picks the parent element whose `<p>` children carry the most text —
  /// on news pages that's reliably the article body — and returns those
  /// paragraphs in document order.
  static List<String> _extractParagraphs(dom.Document doc) {
    final totals = <dom.Element, int>{};
    for (final p in doc.querySelectorAll('p')) {
      final parent = p.parent;
      if (parent == null) continue;
      final len = p.text.trim().length;
      if (len < 40) continue;
      totals[parent] = (totals[parent] ?? 0) + len;
    }
    if (totals.isEmpty) return const [];

    final best =
        (totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    return best.children
        .where((el) => el.localName == 'p')
        .map((p) => p.text.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((t) => t.length >= 30 && !_junk.hasMatch(t))
        .toList();
  }
}
