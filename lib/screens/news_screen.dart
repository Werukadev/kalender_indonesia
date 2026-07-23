import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/holiday.dart';
import '../services/api_service.dart';
import '../services/news_service.dart';
import '../services/news_storage.dart';
import '../widgets/batik.dart';
import 'news_detail_screen.dart';

/// "Berita Hari Ini": aggregated Indonesian news. Coverage of today's
/// holidays (from the calendar API) is searched more widely via Google
/// News and pinned on top; the latest general feed follows below.
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
  late Future<_NewsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
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

  Future<_NewsData> _load() async {
    final holidays = await _todaysHolidays();

    final holidayNewsFutures = holidays
        .take(3)
        .map((h) => NewsService.fetchHolidayNews(
            h.name.replaceAll(RegExp(r'\s*\(.*?\)'), '')))
        .toList();
    final results = await Future.wait([
      NewsService.fetchLatest(),
      ...holidayNewsFutures,
    ]);

    // Persist everything fetched on this device; the returned merged list
    // also restores older/offline items so the feed works without network.
    final holidayFetched =
        results.skip(1).expand((list) => list.take(8)).toList();
    final latest = await NewsStorage.merge([
      ...results.first,
      ...holidayFetched,
    ]);

    final seen = <String>{};
    final holidayNews = <NewsItem>[];
    for (final item in holidayFetched) {
      if (seen.add(item.link)) holidayNews.add(item);
    }

    // Also promote general-feed items that mention today's holiday.
    if (holidays.isNotEmpty) {
      final keywords = holidays.expand((h) => _keywords(h.name)).toSet();
      if (keywords.isNotEmpty) {
        final matched = latest.where((n) {
          final haystack =
              '${n.title} ${n.description ?? ''}'.toLowerCase();
          return keywords.any(haystack.contains);
        }).toList();
        for (final item in matched) {
          if (seen.add(item.link)) holidayNews.insert(0, item);
        }
      }
    }

    holidayNews.sort((a, b) {
      if (a.pubDate == null && b.pubDate == null) return 0;
      if (a.pubDate == null) return 1;
      if (b.pubDate == null) return -1;
      return b.pubDate!.compareTo(a.pubDate!);
    });

    // Whatever ends up pinned in the holiday section must not repeat in
    // the general list below (the merge put everything into `latest`).
    final displayedHoliday = holidayNews.take(10).toList();
    final pinnedLinks = displayedHoliday.map((n) => n.link).toSet();
    latest.removeWhere((n) => pinnedLinks.contains(n.link));

    return _NewsData(
      todaysHolidays: holidays,
      holidayNews: displayedHoliday,
      // The stored history can hold up to 500 items; rendering them all
      // eagerly would jank the list, so show a generous slice.
      latestNews: latest.take(100).toList(),
    );
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
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
      body: FutureBuilder<_NewsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null ||
              (data.holidayNews.isEmpty && data.latestNews.isEmpty)) {
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
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (data.holidayNews.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.celebration_outlined,
                    title: data.todaysHolidays.isEmpty
                        ? 'Berita Utama'
                        : data.todaysHolidays.map((h) => h.name).join(' • '),
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
                      'Kompas • Detik • CNN • Tempo • ANTARA & lainnya',
                ),
                ...data.latestNews.map(
                  (n) => _NewsTile(item: n, onTap: () => _openDetail(n)),
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
              Image.network(
                item.imageUrl!,
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
                child: Image.network(
                  item.imageUrl!,
                  width: 92,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 92, height: 68),
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
