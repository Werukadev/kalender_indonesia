import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Device-local offline cache. Everything the user has already seen keeps
/// working without network: images (holiday banners, news photos, Wikipedia
/// thumbnails) live as files, and content documents (extracted news
/// articles, Wikipedia summaries/bodies, search listings) as JSON.
abstract final class OfflineCache {
  static Future<Directory>? _support;
  static final _imageFutures = <String, Future<File?>>{};
  static final _resolvedImages = <String, File>{};
  static bool _pruneStarted = false;

  /// How long unused cached image files stick around.
  static const _maxAge = Duration(days: 120);

  static Future<Directory> _dir(String namespace) async {
    _support ??= getApplicationSupportDirectory();
    final dir =
        Directory('${(await _support!).path}/offline_cache/$namespace');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Stable file key for arbitrary strings (URLs, titles, queries) —
  /// FNV-1a 64-bit. `String.hashCode` is not stable across sessions.
  static String keyFor(String input) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    return (hash & 0x7fffffffffffffff).toRadixString(16);
  }

  /// Local file for [url]: the cached copy when present, otherwise
  /// downloaded and stored. Null when the image is unavailable and was
  /// never cached (e.g. first view happens offline).
  static Future<File?> imageFile(String url) {
    final pending = _imageFutures[url];
    if (pending != null) return pending;
    final future = _fetchImage(url);
    _imageFutures[url] = future;
    // Failures must not be memoized — a later attempt may have network.
    future.then((file) {
      if (file == null) {
        _imageFutures.remove(url);
      } else {
        _resolvedImages[url] = file;
      }
    });
    return future;
  }

  /// Synchronous lookup for images already resolved this session — lets
  /// list widgets re-render cached images without a loading frame.
  static File? peekImage(String url) => _resolvedImages[url];

  static Future<File?> _fetchImage(String url) async {
    try {
      final dir = await _dir('images');
      _pruneOld(dir);
      final file = File('${dir.path}/${keyFor(url)}.img');
      if (await file.exists()) return file;
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      await file.writeAsBytes(resp.bodyBytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Stores [value] (any json-encodable object) under [namespace]/[key].
  /// Best-effort — caching must never break the caller.
  static Future<void> putJson(
    String namespace,
    String key,
    Object? value,
  ) async {
    try {
      final dir = await _dir(namespace);
      await File('${dir.path}/${keyFor(key)}.json')
          .writeAsString(json.encode(value));
    } catch (_) {}
  }

  /// Reads back a JSON document, or null when absent/corrupt.
  static Future<dynamic> getJson(String namespace, String key) async {
    try {
      final dir = await _dir(namespace);
      final file = File('${dir.path}/${keyFor(key)}.json');
      if (!await file.exists()) return null;
      return json.decode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Once per session: drop image files untouched for [_maxAge], keeping
  /// the cache bounded without a hard size limit.
  static void _pruneOld(Directory dir) {
    if (_pruneStarted) return;
    _pruneStarted = true;
    Future(() async {
      try {
        final cutoff = DateTime.now().subtract(_maxAge);
        await for (final entry in dir.list()) {
          if (entry is! File) continue;
          if ((await entry.stat()).modified.isBefore(cutoff)) {
            try {
              await entry.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}
    });
  }
}
