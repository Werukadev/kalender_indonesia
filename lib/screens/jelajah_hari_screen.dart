import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/holiday.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../widgets/batik.dart';
import 'holiday_detail_screen.dart';

/// "Jelajah Hari": every holiday of the current year as a scrollable feed.
///
/// Two view modes — an Instagram-like card feed (image + title + caption)
/// and a compact list. Both open anchored on today: swipe down for what's
/// coming, swipe up for what has passed. Tapping any item opens the detail
/// page (API description + Wikipedia article).
class JelajahHariScreen extends StatefulWidget {
  const JelajahHariScreen({super.key});

  @override
  State<JelajahHariScreen> createState() => _JelajahHariScreenState();
}

class _JelajahHariScreenState extends State<JelajahHariScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  List<Holiday>? _holidays;
  bool _isLoading = true;
  bool _thumbnailMode = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final year = DateTime.now().year;
    final results = await Future.wait(
      List.generate(12, (i) => _loadMonth(year, i + 1)),
    );
    if (!mounted) return;
    final all = results.expand((list) => list).toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        if (d != 0) return d;
        return a.type.sortOrder.compareTo(b.type.sortOrder);
      });
    setState(() {
      _holidays = all;
      _isLoading = false;
    });
  }

  Future<List<Holiday>> _loadMonth(int year, int month) async {
    try {
      final cached = await _api.getCached(year, month);
      if (cached != null) return cached.holidays;
      final fresh = await _api.fetchFresh(year, month);
      return fresh.holidays;
    } catch (_) {
      return const [];
    }
  }

  void _openDetail(Holiday h) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HolidayDetailScreen(holiday: h)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    final query = _query.trim().toLowerCase();
    final items = (_holidays ?? [])
        .where((h) => settings.isTypeVisible(h.type))
        .where((h) => query.isEmpty || h.name.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: BatikAppBar(
        title: const Text('Jelajah Hari'),
        actions: [
          IconButton(
            icon: Icon(
              _thumbnailMode
                  ? Icons.view_list_outlined
                  : Icons.grid_view_rounded,
            ),
            tooltip: _thumbnailMode ? 'Mode daftar' : 'Mode thumbnail',
            onPressed: () =>
                setState(() => _thumbnailMode = !_thumbnailMode),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Cari hari libur / hari besar...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody(items, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildBody(List<Holiday> items, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'Tidak ada data untuk ditampilkan.'
              : 'Tidak ditemukan hasil untuk "$_query".',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    Widget buildItem(Holiday h) => _thumbnailMode
        ? _FeedCard(holiday: h, onTap: () => _openDetail(h))
        : _ListItem(holiday: h, onTap: () => _openDetail(h));

    // While searching, a plain top-anchored list is what users expect.
    if (_query.trim().isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: items.length,
        itemBuilder: (_, i) => buildItem(items[i]),
      );
    }

    // Anchor the feed on today: items before today grow upward (swipe up
    // for the past), today and later grow downward.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var startIdx = items.indexWhere((h) => !h.date.isBefore(today));
    if (startIdx < 0) startIdx = items.length;
    final past = items.sublist(0, startIdx).reversed.toList();
    final upcoming = items.sublist(startIdx);
    const centerKey = ValueKey('today-anchor');

    return CustomScrollView(
      center: centerKey,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 4),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => buildItem(past[i]),
              childCount: past.length,
            ),
          ),
        ),
        SliverPadding(
          key: centerKey,
          padding: const EdgeInsets.only(bottom: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => buildItem(upcoming[i]),
              childCount: upcoming.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Instagram-like feed card ───────────────────────────────────────────────────

class _FeedCard extends StatelessWidget {
  final Holiday holiday;
  final VoidCallback onTap;

  const _FeedCard({required this.holiday, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = kTypeColors[holiday.type]!;
    final dateLabel = DateFormat('d MMMM yyyy', 'id').format(holiday.date);
    final desc = holiday.description?.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
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
            // Post header: type + date, like an IG account row.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      holiday.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                      ),
                    ),
                  ),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            // Post media: API image, or a colored placeholder banner.
            if (holiday.imageUrl != null)
              Image.network(
                holiday.imageUrl!,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) =>
                    _PlaceholderBanner(color: typeColor),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 140,
                    color: colorScheme.onSurface.withValues(alpha: 0.05),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                },
              )
            else
              _PlaceholderBanner(color: typeColor),
            // Caption: title + description.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Lihat detail & sejarah',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderBanner extends StatelessWidget {
  final Color color;

  const _PlaceholderBanner({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.event_rounded, color: Colors.white70, size: 40),
      ),
    );
  }
}

// ── Compact list item ──────────────────────────────────────────────────────────

class _ListItem extends StatelessWidget {
  final Holiday holiday;
  final VoidCallback onTap;

  const _ListItem({required this.holiday, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = kTypeColors[holiday.type]!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    '${holiday.date.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    DateFormat('MMM', 'id').format(holiday.date),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    holiday.type.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: typeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (holiday.imageUrl != null)
              Icon(
                Icons.image_outlined,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}
