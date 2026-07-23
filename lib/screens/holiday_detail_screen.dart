import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/holiday.dart';
import '../services/wikipedia_service.dart';
import '../widgets/batik.dart';

const kTypeColors = {
  HolidayType.liburNasional: Color(0xFFE53935),
  HolidayType.cutiBersama: Color(0xFFF57C00),
  HolidayType.hariBesarNasional: Color(0xFF1565C0),
  HolidayType.hariBesarInternasional: Color(0xFF7B1FA2),
};

/// Detail view for one holiday: API image + description, plus the relevant
/// article summary pulled live from the Indonesian Wikipedia.
class HolidayDetailScreen extends StatefulWidget {
  final Holiday holiday;

  const HolidayDetailScreen({super.key, required this.holiday});

  @override
  State<HolidayDetailScreen> createState() => _HolidayDetailScreenState();
}

class _HolidayDetailScreenState extends State<HolidayDetailScreen> {
  late final Future<WikipediaResult?> _wikiFuture;

  @override
  void initState() {
    super.initState();
    _wikiFuture = WikipediaService.lookup(widget.holiday.name);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final h = widget.holiday;
    final typeColor = kTypeColors[h.type]!;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id').format(h.date);

    return Scaffold(
      appBar: const BatikAppBar(title: Text('Detail')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (h.imageUrl != null)
            Image.network(
              h.imageUrl!,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    Text(
                      h.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  h.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                if (h.description != null &&
                    h.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    h.description!.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                if (h.sejarah != null) ...[
                  const SizedBox(height: 24),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 17,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Sejarah',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    h.sejarah!.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 17,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Artikel Terkait',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<WikipediaResult?>(
                  future: _wikiFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Mencari artikel Wikipedia...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final wiki = snapshot.data;
                    if (wiki == null) {
                      return Text(
                        'Tidak ditemukan artikel Wikipedia yang relevan.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wiki.extract,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        if (wiki.pageUrl != null) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => _openUrl(wiki.pageUrl!),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
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
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Sumber: Wikipedia bahasa Indonesia — '
                          '"${wiki.title}"',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
