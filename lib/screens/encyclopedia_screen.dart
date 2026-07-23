import 'package:flutter/material.dart';
import '../data/encyclopedia_topics.dart';
import '../widgets/batik.dart';
import 'topic_list_screen.dart';

/// "Ensiklopedia Indonesia" hub: a grid of themed categories (Budaya,
/// Sejarah, Geografi, ...) plus a free-search entry. Each category opens
/// its subtopics; each subtopic lists Wikipedia articles.
class EncyclopediaScreen extends StatelessWidget {
  const EncyclopediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BatikAppBar(title: Text('Ensiklopedia Indonesia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // Free-search entry ("Ensiklopedia Indonesia" itself).
          InkWell(
            borderRadius: BorderRadius.circular(14),
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Text('📖', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cari Artikel',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Artikel tentang berbagai topik yang berkaitan '
                          'dengan Indonesia',
                          style: TextStyle(
                            fontSize: 11.5,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.search,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Without this the grid inherits ambient MediaQuery padding,
            // opening a large gap below the search card.
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemCount: kEncyclopediaCategories.length,
            itemBuilder: (context, i) {
              final category = kEncyclopediaCategories[i];
              return _CategoryCard(category: category);
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final EncyclopediaCategory category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryScreen(category: category),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 26)),
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
            const SizedBox(height: 3),
            Text(
              '${category.subtopics.length} topik',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtopic list for one category (e.g. Budaya → Suku, Rumah Adat, ...).
class CategoryScreen extends StatelessWidget {
  final EncyclopediaCategory category;

  const CategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: BatikAppBar(title: Text('${category.emoji} ${category.name}')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: category.subtopics.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 0.5,
          indent: 16,
          endIndent: 16,
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        itemBuilder: (context, i) {
          final subtopic = category.subtopics[i];
          return ListTile(
            leading: Icon(
              Icons.topic_outlined,
              color: colorScheme.primary,
              size: 22,
            ),
            title: Text(
              subtopic.label,
              style: const TextStyle(fontSize: 14.5),
            ),
            trailing: Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TopicListScreen(
                  title: subtopic.label,
                  initialQuery: subtopic.query,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
