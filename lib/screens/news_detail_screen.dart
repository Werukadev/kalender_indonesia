import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/article_extractor.dart';
import '../services/news_service.dart';
import '../widgets/batik.dart';
import '../widgets/cached_image.dart';

/// Native in-app reader for one news article: the story's text is
/// extracted from the source page and rendered as a clean reading view —
/// no WebView, no leaving the app.
class NewsDetailScreen extends StatefulWidget {
  final NewsItem item;

  const NewsDetailScreen({super.key, required this.item});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late Future<ExtractedArticle?> _future;

  @override
  void initState() {
    super.initState();
    _future = ArticleExtractor.extract(widget.item.link);
  }

  Future<void> _openInBrowser([String? url]) async {
    try {
      await launchUrl(
        Uri.parse(url ?? widget.item.link),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka browser')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: BatikAppBar(
        title: Text(
          widget.item.source,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Buka di browser',
            onPressed: () => _openInBrowser(),
          ),
        ],
      ),
      body: FutureBuilder<ExtractedArticle?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Memuat artikel...', style: TextStyle(fontSize: 12)),
                ],
              ),
            );
          }
          final article = snapshot.data;
          final imageUrl = article?.imageUrl ?? widget.item.imageUrl;
          final title = article?.title ?? widget.item.title;
          final dateLabel = widget.item.pubDate == null
              ? null
              : DateFormat("EEEE, d MMMM yyyy • HH:mm", 'id')
                  .format(widget.item.pubDate!);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              if (imageUrl != null)
                CachedImage(
                  url: imageUrl,
                  width: double.infinity,
                  height: 210,
                  fit: BoxFit.cover,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.item.source,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        if (dateLabel != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dateLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 14),
                    if (article == null || article.paragraphs.isEmpty) ...[
                      if (widget.item.description != null &&
                          widget.item.description!.isNotEmpty)
                        Text(
                          widget.item.description!,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.7,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.85),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        'Isi lengkap artikel tidak dapat dimuat dari '
                        'sumbernya.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openInBrowser(),
                        icon: const Icon(Icons.open_in_new_rounded,
                            size: 16),
                        label: const Text('Baca di situs sumber'),
                      ),
                    ] else ...[
                      for (final paragraph in article.paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            paragraph,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.7,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.87),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _openInBrowser(article.resolvedUrl),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Baca artikel asli di '
                                  '${Uri.parse(article.resolvedUrl).host}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: colorScheme.primary
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
