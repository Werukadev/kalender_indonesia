import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/wikipedia_service.dart';
import '../widgets/batik.dart';

/// Reader page for one Wikipedia article: hero image, lead description,
/// full body text with section headings, and a link to the source page.
class ArticleScreen extends StatefulWidget {
  final String title;

  const ArticleScreen({super.key, required this.title});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late final Future<WikipediaResult?> _summaryFuture;
  late final Future<String?> _textFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = WikipediaService.summaryOf(widget.title);
    _textFuture = WikipediaService.fetchArticleText(widget.title);
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka browser')),
      );
    }
  }

  /// Turns the plain-text extract into paragraph/heading widgets.
  List<Widget> _buildBody(String text, ColorScheme colorScheme) {
    final widgets = <Widget>[];
    for (final block in text.split(RegExp(r'\n{2,}'))) {
      final line = block.trim();
      if (line.isEmpty) continue;
      final heading =
          RegExp(r'^(=+)\s*([^=\n]+?)\s*=+\s*$').firstMatch(line);
      if (heading != null) {
        final isTop = heading.group(1)!.length == 2;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(
            heading.group(2)!,
            style: TextStyle(
              fontSize: isTop ? 16.5 : 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ));
      } else {
        // A block may still contain single newlines + inline headings.
        final cleaned = line.replaceAllMapped(
          RegExp(r'^=+\s*([^=\n]+?)\s*=+\s*$', multiLine: true),
          (m) => m.group(1)!,
        );
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            cleaned,
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: BatikAppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
      ),
      body: FutureBuilder<WikipediaResult?>(
        future: _summaryFuture,
        builder: (context, summarySnap) {
          if (summarySnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = summarySnap.data;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              if (summary?.thumbnailUrl != null)
                Image.network(
                  summary!.thumbnailUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary?.title ?? widget.title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<String?>(
                      future: _textFuture,
                      builder: (context, textSnap) {
                        if (textSnap.connectionState !=
                            ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        final text = textSnap.data ?? summary?.extract;
                        if (text == null || text.isEmpty) {
                          return Text(
                            'Konten artikel tidak tersedia.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildBody(text, colorScheme),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (summary?.pageUrl != null)
                      InkWell(
                        onTap: () => _openUrl(summary!.pageUrl!),
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
                              Text(
                                'Baca selengkapnya di Wikipedia',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: colorScheme.primary
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Sumber: Wikipedia bahasa Indonesia',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
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
