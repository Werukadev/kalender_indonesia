import 'package:flutter/material.dart';
import '../data/encyclopedia_topics.dart';
import '../widgets/batik.dart';
import 'topic_list_screen.dart';

/// "Ensiklopedia Indonesia" hub: a gradient search hero plus a grid of
/// themed categories (Budaya, Sejarah, Geografi, ...). Each category opens
/// its subtopics; each subtopic lists Wikipedia articles.
class EncyclopediaScreen extends StatelessWidget {
  const EncyclopediaScreen({super.key});

  /// Accent hues cycled across category cards — mid tones that stay
  /// readable on both light and dark surfaces.
  static const _accents = [
    Color(0xFFEF5350), // red
    Color(0xFFFF7043), // deep orange
    Color(0xFFFFA726), // amber
    Color(0xFF66BB6A), // green
    Color(0xFF26A69A), // teal
    Color(0xFF42A5F5), // blue
    Color(0xFF5C6BC0), // indigo
    Color(0xFFAB47BC), // purple
    Color(0xFFEC407A), // pink
    Color(0xFF8D6E63), // brown
  ];

  static Color accentFor(int index) => _accents[index % _accents.length];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BatikAppBar(title: Text('Ensiklopedia Indonesia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          const _SearchHero(),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Jelajahi Kategori',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${kEncyclopediaCategories.length} kategori',
                style: TextStyle(
                  fontSize: 11.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Without this the grid inherits ambient MediaQuery padding,
            // opening a large gap below the header row.
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.08,
            ),
            itemCount: kEncyclopediaCategories.length,
            itemBuilder: (context, i) => _CategoryCard(
              category: kEncyclopediaCategories[i],
              accent: accentFor(i),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient banner with the free-search entry, echoing the batik app bar.
class _SearchHero extends StatelessWidget {
  const _SearchHero();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: batikGradient(primary),
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomPaint(
        painter: const BatikKawungPainter(spacing: 42, intensity: 0.8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jelajahi Indonesia',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Budaya, sejarah, tokoh, kuliner, dan banyak lagi — '
                'dari Wikipedia bahasa Indonesia.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TopicListScreen(
                      title: 'Ensiklopedia Indonesia',
                      initialQuery: '',
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white, size: 19),
                      const SizedBox(width: 10),
                      Text(
                        'Cari artikel, tokoh, budaya…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final EncyclopediaCategory category;
  final Color accent;

  const _CategoryCard({required this.category, required this.accent});

  void _open(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CategoryScreen(category: category, accent: accent),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = category.imageAsset;
    if (image != null) return _imageCard(context, image);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _open(context),
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const Spacer(),
              Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${category.subtopics.length} topik',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card variant with the category illustration as background. The name
  /// and badge sit on a translucent dark caption bar (plus a soft scrim
  /// above it) so they stay readable over any artwork, light or busy.
  Widget _imageCard(BuildContext context, String image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(image, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.35, 1],
                colors: [Colors.transparent, Colors.black45],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
              color: Colors.black.withValues(alpha: 0.3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${category.subtopics.length} topik',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Ripple layer on top so taps still give feedback over the image.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _open(context),
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtopic list for one category (e.g. Budaya → Suku, Rumah Adat, ...).
class CategoryScreen extends StatelessWidget {
  final EncyclopediaCategory category;
  final Color? accent;

  const CategoryScreen({super.key, required this.category, this.accent});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = accent ?? colorScheme.primary;

    return Scaffold(
      appBar: BatikAppBar(title: Text(category.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          // Category banner: the illustration when available, otherwise
          // the accent gradient. A scrim keeps the white text readable.
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: category.imageAsset == null
                  ? batikGradient(accentColor)
                  : null,
              image: category.imageAsset == null
                  ? null
                  : DecorationImage(
                      image: AssetImage(category.imageAsset!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: category.imageAsset == null
                  ? null
                  : const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // ~20% → ~45% black: light veil, just enough for
                        // the white texts over light artwork.
                        colors: [Color(0x33000000), Color(0x73000000)],
                      ),
                    ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${category.subtopics.length} topik • '
                          'Artikel dari Wikipedia',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final subtopic in category.subtopics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopicListScreen(
                      title: subtopic.label,
                      initialQuery: subtopic.query,
                    ),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subtopic.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _capitalize(subtopic.query),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
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
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
