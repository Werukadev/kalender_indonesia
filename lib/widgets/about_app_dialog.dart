import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutAppDialog extends StatefulWidget {
  const AboutAppDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AboutAppDialog(),
    );
  }

  @override
  State<AboutAppDialog> createState() => _AboutAppDialogState();
}

class _AboutAppDialogState extends State<AboutAppDialog> {
  String _version = '';
  String _buildNumber = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
        _loaded = true;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showError();
      }
    } catch (_) {
      _showError();
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tidak dapat membuka browser')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final versionLabel = !_loaded
        ? '...'
        : _buildNumber.isEmpty
            ? 'Versi $_version'
            : 'Versi $_version ($_buildNumber)';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Kalender Indonesia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          versionLabel,
                          key: ValueKey(versionLabel),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    splashRadius: 20,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),

            _divider(colorScheme),

            // ── Tentang Aplikasi ──────────────────────────────────────────────
            _InfoSection(
              icon: Icons.info_outline_rounded,
              title: 'Tentang Aplikasi',
              colorScheme: colorScheme,
              child: Text(
                'Aplikasi kalender Indonesia yang menampilkan informasi '
                'hari libur nasional, cuti bersama, hari besar nasional, '
                'dan hari besar internasional secara lengkap.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),

            _dividerIndent(colorScheme),

            // ── Sumber Data ───────────────────────────────────────────────────
            _InfoSection(
              icon: Icons.storage_outlined,
              title: 'Sumber Data API',
              colorScheme: colorScheme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data hari libur bersumber dari:',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _UrlTile(
                    label: 'cal.weruka.dev/api/holidays',
                    colorScheme: colorScheme,
                    onTap: () => _openUrl('https://cal.weruka.dev/api/holidays'),
                  ),
                ],
              ),
            ),

            _divider(colorScheme),

            // ── Developer Website ─────────────────────────────────────────────
            InkWell(
              onTap: () => _openUrl('https://www.weruka.dev'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'www.weruka.dev',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            colorScheme.primary.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) => Divider(
        height: 1,
        thickness: 0.5,
        color: cs.onSurface.withValues(alpha: 0.1),
      );

  Widget _dividerIndent(ColorScheme cs) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 20,
        endIndent: 20,
        color: cs.onSurface.withValues(alpha: 0.08),
      );
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final ColorScheme colorScheme;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.child,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: colorScheme.primary),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _UrlTile extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _UrlTile({
    required this.label,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_new_rounded,
              size: 13,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: colorScheme.primary.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
