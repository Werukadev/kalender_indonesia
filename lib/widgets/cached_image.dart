import 'dart:io';

import 'package:flutter/material.dart';
import '../services/offline_cache.dart';

/// Drop-in replacement for `Image.network` backed by [OfflineCache]:
/// every image shown once is stored on the device and keeps rendering
/// offline afterwards.
class CachedImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;

  /// Shown when the image is unavailable (bad URL, or offline and never
  /// cached). Defaults to an empty box.
  final Widget? error;

  /// Shown while the image is being resolved/downloaded. Defaults to an
  /// empty box reserving [width]/[height] when they are finite.
  final Widget? loading;

  const CachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.error,
    this.loading,
  });

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  late Future<File?> _future;

  @override
  void initState() {
    super.initState();
    _future = OfflineCache.imageFile(widget.url);
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = OfflineCache.imageFile(widget.url);
    }
  }

  Widget _image(File file) {
    return Image.file(
      file,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, _, _) => widget.error ?? const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Already resolved this session (e.g. a list item scrolling back into
    // view) — render synchronously, no loading frame.
    final resolved = OfflineCache.peekImage(widget.url);
    if (resolved != null) return _image(resolved);

    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loading ??
              SizedBox(
                width: (widget.width?.isFinite ?? false)
                    ? widget.width
                    : null,
                height: widget.height,
              );
        }
        final file = snapshot.data;
        if (file == null) return widget.error ?? const SizedBox.shrink();
        return _image(file);
      },
    );
  }
}
