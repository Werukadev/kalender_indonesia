import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../services/offline_cache.dart';
import '../services/pexels_service.dart';
import '../widgets/batik.dart';
import '../widgets/cached_image.dart';

/// Promo footer appended to every share (same wording as event sharing).
const _shareFooter =
    '📅 Dibagikan dari aplikasi Kalender Indonesia\n'
    'Unduh gratis di Play Store:\n'
    'https://play.google.com/store/apps/details?id=cal.weruka.dev';

/// Local .jpg copy of a (cached) image — share sheets and the gallery
/// need a real image extension, not OfflineCache's ".img".
Future<File?> _localImageCopy(String url) async {
  final cached = await OfflineCache.imageFile(url);
  if (cached == null) return null;
  final dir = await getTemporaryDirectory();
  final out = File('${dir.path}/pexels_${OfflineCache.keyFor(url)}.jpg');
  if (!await out.exists()) await cached.copy(out.path);
  return out;
}

/// Local .mp4 copy of a video (downloaded once, reused by share and
/// download-to-gallery).
Future<File?> _localVideoCopy(PexelsMedia media) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pexels_${media.id}.mp4');
    if (await file.exists()) return file;
    final resp = await http
        .get(Uri.parse(media.videoUrl!))
        .timeout(const Duration(minutes: 3));
    if (resp.statusCode != 200) return null;
    await file.writeAsBytes(resp.bodyBytes);
    return file;
  } catch (_) {
    return null;
  }
}

/// Shares a gallery item as an actual media FILE (photo .jpg / video
/// .mp4) — downloaded locally first, so recipients get the content, not
/// a Pexels URL. Always captioned with attribution + the promo footer.
Future<void> shareGaleriMedia(BuildContext context, PexelsMedia media) async {
  final messenger = ScaffoldMessenger.of(context);
  final author = media.author.isEmpty ? 'Pexels' : media.author;
  final caption = [
    if (media.alt != null) media.alt!,
    '${media.isVideo ? 'Video' : 'Foto'} oleh $author — Pexels',
    '',
    _shareFooter,
  ].join('\n');
  try {
    File? file;
    if (media.isVideo) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Menyiapkan video untuk dibagikan...')),
      );
      file = await _localVideoCopy(media);
      messenger.hideCurrentSnackBar();
    } else {
      file = await _localImageCopy(media.fullUrl ?? media.thumbUrl);
    }
    if (file != null) {
      if (media.isVideo) {
        // Most target apps (WhatsApp included) drop the accompanying text
        // when the shared file is a video — the receiving app decides,
        // nothing to force from our side. Put the caption+footer on the
        // clipboard instead so the user can paste it in one tap.
        await Clipboard.setData(ClipboardData(text: caption));
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Teks caption sudah disalin — tempel (paste) di kolom '
              'caption saat membagikan video.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: media.isVideo ? 'video/mp4' : 'image/jpeg',
            ),
          ],
          text: caption,
        ),
      );
      return;
    }
    // Content couldn't be fetched (offline?) — share the text as a last
    // resort rather than failing silently.
    await SharePlus.instance.share(ShareParams(text: caption));
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Tidak dapat membagikan media.')),
    );
  }
}

/// Downloads a gallery item into the device gallery (album
/// "Kalender Indonesia").
Future<void> downloadGaleriMedia(
  BuildContext context,
  PexelsMedia media,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(media.isVideo ? 'Mengunduh video...' : 'Menyimpan foto...'),
    ),
  );
  try {
    if (media.isVideo) {
      final file = await _localVideoCopy(media);
      if (file == null) throw Exception('video unavailable');
      await Gal.putVideo(file.path, album: 'Kalender Indonesia');
    } else {
      final file = await _localImageCopy(media.fullUrl ?? media.thumbUrl);
      if (file == null) throw Exception('image unavailable');
      await Gal.putImage(file.path, album: 'Kalender Indonesia');
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Tersimpan ke galeri perangkat 🎉')),
    );
  } on GalException {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Gagal menyimpan — izin galeri ditolak.')),
    );
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Gagal mengunduh media.')),
    );
  }
}

/// "Galeri Nusantara": an Instagram-style, endlessly scrolling feed of
/// photos and videos from Pexels. Defaults to Indonesian themes and
/// today's holidays; a search field narrows it to anything. Queries and
/// result pages are shuffled per session, so every open/refresh looks
/// different.
class GaleriScreen extends StatefulWidget {
  const GaleriScreen({super.key});

  @override
  State<GaleriScreen> createState() => _GaleriScreenState();
}

class _GaleriScreenState extends State<GaleriScreen> {
  /// Big shuffled pool of Indonesian themes. The wider the pool, the
  /// smaller the chance two visits ever look the same — combined with
  /// random result pages, the feed reads as "always fresh".
  static const _defaultTopics = [
    // Umum & tempat
    'indonesia',
    'bali',
    'jakarta',
    'yogyakarta',
    'bandung',
    'surabaya',
    'lombok',
    'borobudur',
    'prambanan',
    'candi indonesia',
    'kota tua jakarta',
    'monas jakarta',
    'pura bali',
    'masjid indonesia',
    // Alam
    'pantai indonesia',
    'gunung bromo',
    'kawah ijen',
    'raja ampat',
    'danau toba',
    'komodo',
    'nusa penida',
    'air terjun indonesia',
    'sawah terasering',
    'hutan tropis indonesia',
    'terumbu karang indonesia',
    'sunset indonesia',
    'laut indonesia',
    'gunung indonesia',
    // Budaya & seni
    'budaya indonesia',
    'batik',
    'wayang',
    'tari tradisional indonesia',
    'tari bali',
    'tari kecak',
    'reog ponorogo',
    'barong bali',
    'gamelan',
    'angklung',
    'alat musik tradisional',
    'upacara adat indonesia',
    'pakaian adat indonesia',
    'rumah adat indonesia',
    'kain tenun indonesia',
    'songket',
    'aksara jawa',
    'kaligrafi indonesia',
    'ondel ondel',
    'karnaval indonesia',
    // Kehidupan sehari-hari
    'pasar tradisional indonesia',
    'nelayan indonesia',
    'petani indonesia',
    'becak',
    'kampung indonesia',
    'anak indonesia bermain',
    // Kuliner
    'kuliner indonesia',
    'nasi goreng',
    'sate',
    'rendang',
    'kopi indonesia',
    'jajanan pasar',
    'street food indonesia',
  ];

  final _items = <PexelsMedia>[];
  final _seenKeys = <String>{};
  final _random = Random();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<String> _queryPool = const [];
  int _poolIndex = 0;
  String? _searchQuery; // null = default Indonesia/holiday feed
  int _searchPage = 1;
  bool _loading = false;
  bool _initialLoading = true;
  bool _fromOfflineCache = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _restart();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.extentAfter < 900) _loadMore();
  }

  /// Clears the feed and rebuilds the shuffled query pool — called on
  /// first open, pull-to-refresh, and when leaving search mode. The
  /// shuffle (plus random result pages) is what keeps every visit fresh.
  Future<void> _restart() async {
    _items.clear();
    _seenKeys.clear();
    _poolIndex = 0;
    _searchPage = 1;
    _initialLoading = true;
    _fromOfflineCache = false;
    if (mounted) setState(() {});

    if (_searchQuery == null) {
      final pool = List.of(_defaultTopics)..shuffle(_random);
      // Today's holidays lead the feed when available.
      pool.insertAll(0, await _todaysHolidayQueries());
      _queryPool = pool;
    }
    await _loadMore();
  }

  Future<List<String>> _todaysHolidayQueries() async {
    try {
      final now = DateTime.now();
      final cached = await ApiService().getCached(now.year, now.month);
      if (cached == null) return const [];
      return cached.holidays
          .where(
            (h) =>
                h.date.year == now.year &&
                h.date.month == now.month &&
                h.date.day == now.day,
          )
          .map((h) => h.name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim())
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    _loading = true;
    if (mounted) setState(() {});
    try {
      var batch = <PexelsMedia>[];
      if (_searchQuery != null) {
        // Search mode: sequential pages for proper relevance + pagination.
        batch = await _fetchBatch(_searchQuery!, _searchPage, _searchPage);
        _searchPage++;
      } else {
        // Default mode: next shuffled query, random pages — a holiday name
        // may match nothing on Pexels, so skip ahead a few times if empty.
        for (var attempt = 0; attempt < 3 && batch.isEmpty; attempt++) {
          if (_queryPool.isEmpty) break;
          final query = _queryPool[_poolIndex++ % _queryPool.length];
          batch = await _fetchBatch(
            query,
            1 + _random.nextInt(8),
            1 + _random.nextInt(3),
          );
        }
      }

      final fresh = batch.where((m) => _seenKeys.add(m.key)).toList()
        ..shuffle(_random);
      if (fresh.isNotEmpty) {
        _items.addAll(fresh);
        if (_searchQuery == null) PexelsService.saveFeedSnapshot(_items);
      }

      // Offline on a fresh open: fall back to the last stored feed.
      if (_items.isEmpty && _searchQuery == null) {
        final snapshot = await PexelsService.cachedFeedSnapshot();
        if (snapshot.isNotEmpty) {
          _items.addAll(snapshot.where((m) => _seenKeys.add(m.key)));
          _fromOfflineCache = true;
        }
      }
    } finally {
      _loading = false;
      _initialLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<List<PexelsMedia>> _fetchBatch(
    String query,
    int photoPage,
    int videoPage,
  ) async {
    final photosF = PexelsService.searchPhotos(query, page: photoPage);
    final videosF = PexelsService.searchVideos(query, page: videoPage);
    return [...await photosF, ...await videosF];
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final q = value.trim();
      final next = q.isEmpty ? null : q;
      if (next == _searchQuery) return;
      _searchQuery = next;
      _restart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BatikAppBar(title: Text('Galeri Nusantara')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari foto & video...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_fromOfflineCache)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
              child: Text(
                'Offline — menampilkan galeri terakhir yang tersimpan.',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          Expanded(child: _buildFeed(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildFeed(ColorScheme colorScheme) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 34,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10),
            Text(
              _searchQuery == null
                  ? 'Tidak dapat memuat galeri.\nPeriksa koneksi internet Anda.'
                  : 'Tidak ada hasil untuk "$_searchQuery".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _restart, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _restart,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 24),
        // +1 for the bottom loading indicator row.
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Sumber: Pexels',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
              ),
            );
          }
          return _MediaCard(
            media: _items[i],
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    _MediaPager(items: List.of(_items), initialIndex: i),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One Instagram-style feed card: author header, the photo/video, and a
/// caption + Pexels attribution footer.
class _MediaCard extends StatelessWidget {
  final PexelsMedia media;

  /// Opens the fullscreen pager at this card's feed position.
  final VoidCallback onOpen;

  const _MediaCard({required this.media, required this.onOpen});

  String _durationLabel(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final author = media.author.isEmpty ? 'Pexels' : media.author;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: author + media-type chip.
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    author[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    media.isVideo ? '🎬 Video' : '📷 Foto',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Media. Aspect ratio clamped so extreme panoramas/portraits
          // don't dominate the feed.
          GestureDetector(
            onTap: onOpen,
            child: AspectRatio(
              aspectRatio: media.aspectRatio.clamp(0.75, 1.6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedImage(
                    url: media.thumbUrl,
                    fit: BoxFit.cover,
                    error: Container(
                      color: colorScheme.onSurface.withValues(alpha: 0.06),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  if (media.isVideo) ...[
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    if (media.durationSec != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _durationLabel(media.durationSec!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          // Caption, attribution + share/download actions.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (media.alt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, right: 6),
                    child: Text(
                      media.alt!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                  ),
                Text(
                  '${media.isVideo ? 'Video' : 'Foto'} oleh $author • Pexels',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fullscreen viewer over the whole feed: swipe left/right to move
/// between items (photos zoomable, videos playing only while their page
/// is the active one).
class _MediaPager extends StatefulWidget {
  final List<PexelsMedia> items;
  final int initialIndex;

  const _MediaPager({required this.items, required this.initialIndex});

  @override
  State<_MediaPager> createState() => _MediaPagerState();
}

class _MediaPagerState extends State<_MediaPager> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.items[_current];
    final author = media.author.isEmpty ? 'Pexels' : media.author;

    return Scaffold(
      backgroundColor: Colors.black,
      // Media fills the whole screen (behind the translucent app bar), so
      // photos/videos sit dead-center instead of being pushed down.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              author,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_current + 1} / ${widget.items.length} • '
              '${media.isVideo ? 'Video' : 'Foto'} • Pexels',
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Bagikan',
            onPressed: () => shareGaleriMedia(context, media),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Unduh ke galeri',
            onPressed: () => downloadGaleriMedia(context, media),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) {
          final item = widget.items[i];
          return item.isVideo
              ? _VideoPage(media: item, active: i == _current)
              : _PhotoPage(media: item);
        },
      ),
    );
  }
}

/// One zoomable photo page. Pinch to zoom; pan is disabled at rest so a
/// horizontal drag keeps swiping the pager instead of being swallowed.
class _PhotoPage extends StatelessWidget {
  final PexelsMedia media;

  const _PhotoPage({required this.media});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        maxScale: 5,
        panEnabled: false,
        child: CachedImage(
          url: media.fullUrl ?? media.thumbUrl,
          fit: BoxFit.contain,
          width: double.infinity,
        ),
      ),
    );
  }
}

/// One video page. The player is created lazily the first time the page
/// becomes active (neighbors pre-built by PageView don't buffer), pauses
/// whenever it's swiped away, and resumes when swiped back.
class _VideoPage extends StatefulWidget {
  final PexelsMedia media;
  final bool active;

  const _VideoPage({required this.media, required this.active});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _initController();
  }

  @override
  void didUpdateWidget(_VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (_controller == null) {
        _initController();
      } else if (_ready) {
        _controller!.play();
      }
    } else if (!widget.active && oldWidget.active) {
      _controller?.pause();
    }
  }

  void _initController() {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.media.videoUrl!),
    );
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          controller.setLooping(true);
          if (widget.active) controller.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'Video tidak dapat diputar.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !_ready) {
      // Thumbnail placeholder while idle/buffering.
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedImage(url: widget.media.thumbUrl, fit: BoxFit.contain),
          if (widget.active) const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        controller.value.isPlaying ? controller.pause() : controller.play();
      }),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
          ),
        ],
      ),
    );
  }
}
