import 'dart:convert';

import 'package:http/http.dart' as http;
import 'offline_cache.dart';

/// One feed item from Pexels — a photo or a video.
class PexelsMedia {
  final int id;
  final bool isVideo;

  /// Image shown in the feed card (photo "large" / video thumbnail).
  final String thumbUrl;

  /// Hi-res image for the fullscreen viewer (photos only).
  final String? fullUrl;

  /// Best playable MP4 link (videos only).
  final String? videoUrl;

  final String author;
  final String? alt;
  final double aspectRatio; // width / height
  final int? durationSec; // videos only

  /// The media's page on pexels.com — used in share texts.
  final String? pageUrl;

  const PexelsMedia({
    required this.id,
    required this.isVideo,
    required this.thumbUrl,
    required this.author,
    required this.aspectRatio,
    this.fullUrl,
    this.videoUrl,
    this.alt,
    this.durationSec,
    this.pageUrl,
  });

  /// Unique across the mixed photo/video feed.
  String get key => isVideo ? 'v$id' : 'p$id';

  Map<String, dynamic> toJson() => {
    'id': id,
    'isVideo': isVideo,
    'thumbUrl': thumbUrl,
    'author': author,
    'aspectRatio': aspectRatio,
    if (fullUrl != null) 'fullUrl': fullUrl,
    if (videoUrl != null) 'videoUrl': videoUrl,
    if (alt != null) 'alt': alt,
    if (durationSec != null) 'durationSec': durationSec,
    if (pageUrl != null) 'pageUrl': pageUrl,
  };

  factory PexelsMedia.fromJson(Map<String, dynamic> json) => PexelsMedia(
    id: json['id'] as int,
    isVideo: json['isVideo'] as bool? ?? false,
    thumbUrl: json['thumbUrl'] as String,
    author: json['author'] as String? ?? '',
    aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 1,
    fullUrl: json['fullUrl'] as String?,
    videoUrl: json['videoUrl'] as String?,
    alt: json['alt'] as String?,
    durationSec: json['durationSec'] as int?,
    pageUrl: json['pageUrl'] as String?,
  );
}

/// Pexels search API (photos + videos). Free tier; attribution to Pexels
/// and the photographer is shown on every card, per Pexels guidelines.
abstract final class PexelsService {
  static const _apiKey =
      'ztxRYpvhY9Evg44BEziGYdLcDHq0lLmV9vDGEiUlzzeZwOzgI8k4Xrek';
  static const _headers = {'Authorization': _apiKey};
  static const _ns = 'pexels';

  /// Photos matching [query]. Empty list on failure — the feed just moves
  /// on to its next query.
  static Future<List<PexelsMedia>> searchPhotos(
    String query, {
    int page = 1,
    int perPage = 12,
  }) async {
    final uri = Uri.https('api.pexels.com', '/v1/search', {
      'query': query,
      'page': '$page',
      'per_page': '$perPage',
      'locale': 'id-ID',
    });
    final data = await _getJson(uri);
    final photos = data?['photos'];
    if (photos is! List) return const [];
    return photos
        .whereType<Map<String, dynamic>>()
        .map(_photoFromJson)
        .whereType<PexelsMedia>()
        .toList();
  }

  /// Videos matching [query].
  static Future<List<PexelsMedia>> searchVideos(
    String query, {
    int page = 1,
    int perPage = 4,
  }) async {
    final uri = Uri.https('api.pexels.com', '/videos/search', {
      'query': query,
      'page': '$page',
      'per_page': '$perPage',
      'locale': 'id-ID',
    });
    final data = await _getJson(uri);
    final videos = data?['videos'];
    if (videos is! List) return const [];
    return videos
        .whereType<Map<String, dynamic>>()
        .map(_videoFromJson)
        .whereType<PexelsMedia>()
        .toList();
  }

  /// Persists the current default feed so the page still shows something
  /// (with already-cached images) when opened offline.
  static Future<void> saveFeedSnapshot(List<PexelsMedia> items) =>
      OfflineCache.putJson(
        _ns,
        'feed_snapshot',
        items.take(30).map((m) => m.toJson()).toList(),
      );

  static Future<List<PexelsMedia>> cachedFeedSnapshot() async {
    final cached = await OfflineCache.getJson(_ns, 'feed_snapshot');
    if (cached is! List) return const [];
    return cached
        .whereType<Map<String, dynamic>>()
        .map(PexelsMedia.fromJson)
        .toList();
  }

  static PexelsMedia? _photoFromJson(Map<String, dynamic> json) {
    final src = json['src'];
    if (src is! Map<String, dynamic>) return null;
    final thumb = (src['large'] ?? src['medium']) as String?;
    if (thumb == null || json['id'] is! int) return null;
    final width = (json['width'] as num?)?.toDouble();
    final height = (json['height'] as num?)?.toDouble();
    final alt = (json['alt'] as String?)?.trim();
    return PexelsMedia(
      id: json['id'] as int,
      isVideo: false,
      thumbUrl: thumb,
      fullUrl: (src['large2x'] ?? src['large']) as String?,
      author: (json['photographer'] as String?) ?? '',
      alt: (alt == null || alt.isEmpty) ? null : alt,
      pageUrl: json['url'] as String?,
      aspectRatio: (width != null && height != null && height > 0)
          ? width / height
          : 1,
    );
  }

  static PexelsMedia? _videoFromJson(Map<String, dynamic> json) {
    if (json['id'] is! int) return null;
    final thumb = json['image'] as String?;
    if (thumb == null) return null;

    // Pick the smallest MP4 that is still ≥720px wide (or the largest
    // available below that) — sharp enough without burning bandwidth.
    String? link;
    var bestWidth = 0;
    final files = json['video_files'];
    if (files is List) {
      for (final f in files.whereType<Map<String, dynamic>>()) {
        if (f['file_type'] != 'video/mp4') continue;
        final w = (f['width'] as num?)?.toInt() ?? 0;
        final l = f['link'] as String?;
        if (l == null || w == 0) continue;
        final better = bestWidth < 720
            ? w > bestWidth
            : (w >= 720 && w < bestWidth);
        if (better) {
          bestWidth = w;
          link = l;
        }
      }
    }
    if (link == null) return null;

    final width = (json['width'] as num?)?.toDouble();
    final height = (json['height'] as num?)?.toDouble();
    final user = json['user'];
    return PexelsMedia(
      id: json['id'] as int,
      isVideo: true,
      thumbUrl: thumb,
      videoUrl: link,
      author: user is Map<String, dynamic>
          ? ((user['name'] as String?) ?? '')
          : '',
      pageUrl: json['url'] as String?,
      durationSec: (json['duration'] as num?)?.toInt(),
      aspectRatio: (width != null && height != null && height > 0)
          ? width / height
          : 1,
    );
  }

  static Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    try {
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      return json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
