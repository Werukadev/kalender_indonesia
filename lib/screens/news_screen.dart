import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/holiday.dart';
import '../services/api_service.dart';
import '../services/news_service.dart';
import '../services/news_storage.dart';
import '../widgets/batik.dart';
import '../widgets/cached_image.dart';
import 'news_detail_screen.dart';

/// "Berita Hari Ini": aggregated Indonesian news. General-feed items that
/// mention today's holidays (from the calendar API) are pinned on top;
/// the latest general feed follows below.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsData {
  final List<Holiday> todaysHolidays;
  final List<NewsItem> holidayNews;
  final List<NewsItem> latestNews;

  const _NewsData({
    required this.todaysHolidays,
    required this.holidayNews,
    required this.latestNews,
  });
}

class _NewsScreenState extends State<NewsScreen> {
  final _api = ApiService();
  _NewsData? _data;
  bool _refreshing = false;
  List<Holiday> _holidays = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Instant-first loading: the stored history renders immediately with no
  /// network wait, then the feeds refresh in the background and the list
  /// updates in place. The full-screen spinner only ever appears on the
  /// very first open, when nothing is stored yet.
  Future<void> _init() async {
    _holidays = await _todaysHolidays();
    final stored = await NewsStorage.load();
    final visible = stored.where((n) => n.imageUrl != null).toList();
    if (mounted && visible.isNotEmpty) {
      setState(() => _data = _buildData(visible));
    }
    await _refresh();
  }

  Future<List<Holiday>> _todaysHolidays() async {
    final now = DateTime.now();
    try {
      final cached = await _api.getCached(now.year, now.month);
      final holidays =
          cached?.holidays ?? (await _api.fetchFresh(now.year, now.month)).holidays;
      return holidays
          .where((h) =>
              h.date.year == now.year &&
              h.date.month == now.month &&
              h.date.day == now.day)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Distinctive words of a holiday name, for matching general-feed items.
  static List<String> _keywords(String name) {
    const generic = {
      'hari', 'nasional', 'internasional', 'sedunia', 'dunia', 'dan',
      'untuk', 'para', 'di', 'ke',
    };
    return name
        .replaceAll(RegExp(r'\s*\(.*?\)'), '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !generic.contains(w))
        .toList();
  }

  /// Splits [latest] (newest-first, image-filtered) into the pinned
  /// holiday section and the general list below it.
  _NewsData _buildData(List<NewsItem> latest) {
    // Pin general-feed items that mention today's holiday. `latest` is
    // already sorted newest-first, so the pinned list inherits that order.
    final holidayNews = <NewsItem>[];
    if (_holidays.isNotEmpty) {
      final keywords = _holidays.expand((h) => _keywords(h.name)).toSet();
      if (keywords.isNotEmpty) {
        holidayNews.addAll(latest.where((n) {
          final haystack =
              '${n.title} ${n.description ?? ''}'.toLowerCase();
          return keywords.any(haystack.contains);
        }));
      }
    }

    // Whatever ends up pinned in the holiday section must not repeat in
    // the general list below.
    final displayedHoliday = holidayNews.take(10).toList();
    final pinnedLinks = displayedHoliday.map((n) => n.link).toSet();
    final general =
        latest.where((n) => !pinnedLinks.contains(n.link)).toList();

    return _NewsData(
      todaysHolidays: _holidays,
      holidayNews: displayedHoliday,
      // The stored history can hold up to 500 items; rendering them all
      // eagerly would jank the list, so show a generous slice.
      latestNews: general.take(100).toList(),
    );
  }

  /// Fetches the feeds, persists them, and swaps the fresher list in.
  /// The already-rendered stored list stays on screen the whole time.
  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});
    try {
      final merged =
          await NewsStorage.merge(await NewsService.fetchLatest());
      // Older stored items (and former Google News entries) may predate
      // the banner-image requirement — only items with an image show.
      final visible = merged.where((n) => n.imageUrl != null).toList();
      if (mounted && visible.isNotEmpty) {
        setState(() => _data = _buildData(visible));
      }
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  void _openDetail(NewsItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewsDetailScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateLabel =
        DateFormat('EEEE, d MMMM yyyy', 'id').format(DateTime.now());

    return Scaffold(
      appBar: BatikAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Berita Hari Ini'),
            Text(
              dateLabel,
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (context) {
          final data = _data;
          if (data == null ||
              (data.holidayNews.isEmpty && data.latestNews.isEmpty)) {
            // Nothing stored yet (very first open): spinner while the
            // feeds load. Every later open renders instantly from storage.
            if (_refreshing) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 34,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tidak dapat memuat berita.\nPeriksa koneksi internet Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (data.holidayNews.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.celebration_outlined,
                        title: data.todaysHolidays.isEmpty
                            ? 'Berita Utama'
                            : data.todaysHolidays
                                .map((h) => h.name)
                                .join(' • '),
                        subtitle: 'Berita terkait hari penting hari ini',
                      ),
                      ...data.holidayNews.map(
                        (n) => _FeaturedNewsCard(
                          item: n,
                          onTap: () => _openDetail(n),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    _SectionHeader(
                      icon: Icons.newspaper_outlined,
                      title: 'Berita Terkini',
                      subtitle:
                          'CNN • Detik • Tempo • ANTARA & lainnya',
                    ),
                    ...data.latestNews.map(
                      (n) => _NewsTile(item: n, onTap: () => _openDetail(n)),
                    ),
                  ],
                ),
                // Slim bar while the background refresh is running — the
                // stored list stays visible and usable beneath it.
                if (_refreshing)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2.5),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _relativeTime(DateTime? date) {
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return DateFormat('d MMM yyyy', 'id').format(date);
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
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

/// Big card with full-width image — used for holiday-related headlines.
class _FeaturedNewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;

  const _FeaturedNewsCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null)
              CachedImage(
                url: item.imageUrl!,
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SourceChip(source: item.source),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(item.pubDate),
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty &&
                      item.description != item.title) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row tile for the general latest-news list.
class _NewsTile extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;

  const _NewsTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _SourceChip(source: item.source),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _relativeTime(item.pubDate),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (item.imageUrl != null) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: CachedImage(
                  url: item.imageUrl!,
                  width: 92,
                  height: 68,
                  fit: BoxFit.cover,
                  error: const SizedBox(width: 92, height: 68),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String source;

  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        source,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
