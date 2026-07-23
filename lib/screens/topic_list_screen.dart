import 'dart:async';

import 'package:flutter/material.dart';
import '../services/wikipedia_service.dart';
import '../widgets/batik.dart';
import 'article_screen.dart';

/// Article list for one encyclopedia subtopic — search results from the
/// Indonesian Wikipedia, refinable through the search field. Also serves as
/// the free-search "Ensiklopedia Indonesia" page when [initialQuery] is
/// empty.
class TopicListScreen extends StatefulWidget {
  final String title;
  final String initialQuery;

  const TopicListScreen({
    super.key,
    required this.title,
    required this.initialQuery,
  });

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  Future<List<WikiSearchItem>>? _resultsFuture;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _activeQuery = widget.initialQuery;
      _resultsFuture = WikipediaService.searchArticles(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final q = value.trim();
      // Empty input falls back to the subtopic's default listing.
      final query = q.isEmpty ? widget.initialQuery : q;
      if (query == _activeQuery) return;
      setState(() {
        _activeQuery = query;
        _resultsFuture =
            query.isEmpty ? null : WikipediaService.searchArticles(query);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: BatikAppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              autofocus: widget.initialQuery.isEmpty,
              decoration: InputDecoration(
                hintText: 'Cari artikel...',
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
          Expanded(child: _buildResults(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme colorScheme) {
    if (_resultsFuture == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ketik kata kunci untuk mencari artikel tentang Indonesia.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return FutureBuilder<List<WikiSearchItem>>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <WikiSearchItem>[];
        if (items.isEmpty) {
          return Center(
            child: Text(
              'Tidak ditemukan artikel untuk "$_activeQuery".',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, i) {
            final item = items[i];
            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArticleScreen(title: item.title),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: item.thumbnailUrl != null
                            ? Image.network(
                                item.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _thumbFallback(colorScheme),
                              )
                            : _thumbFallback(colorScheme),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ],
                      ),
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
          },
        );
      },
    );
  }

  Widget _thumbFallback(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.primary.withValues(alpha: 0.1),
      child: Icon(
        Icons.article_outlined,
        color: colorScheme.primary.withValues(alpha: 0.6),
        size: 24,
      ),
    );
  }
}
