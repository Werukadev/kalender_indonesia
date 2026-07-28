import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/preload_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _preload = PreloadService(ApiService());

  double _progress = 0;
  String _statusLabel = '';
  bool _isDownloading = false;
  bool _showPrompt = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final needs = await PreloadService.needsPreload();
    if (!mounted) return;

    if (!needs) {
      _goHome();
      return;
    }

    // App Store guideline 4.2.3(ii): disclose the download size and let the
    // user choose before fetching additional resources.
    setState(() => _showPrompt = true);
  }

  Future<void> _startDownload() async {
    setState(() {
      _showPrompt = false;
      _isDownloading = true;
    });

    final now = DateTime.now();
    await for (final p in _preload.prefetch([now.year, now.year + 1])) {
      if (!mounted) return;
      setState(() {
        _progress = p.fraction;
        _statusLabel = p.currentLabel;
      });
    }

    await PreloadService.markDone();
    if (mounted) _goHome();
  }

  Future<void> _skipDownload() async {
    await PreloadService.markSkipped();
    if (mounted) _goHome();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Logo + title ────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo-app.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Kalender Indonesia',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hari libur, cuti bersama & hari besar',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Download consent prompt ─────────────────────────────────────
            if (_showPrompt)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_download_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Unduh Data Kalender',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aplikasi dapat mengunduh data hari libur & hari besar '
                        'untuk ${DateTime.now().year}–${DateTime.now().year + 1} '
                        '(ukuran unduhan ${PreloadService.downloadSizeLabel}) '
                        'agar kalender bisa diakses offline.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jika dilewati, data dimuat saat dibutuhkan '
                        '(memerlukan koneksi internet).',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _startDownload,
                              child: Text(
                                'Unduh (${PreloadService.downloadSizeLabel})',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: _skipDownload,
                            child: Text(
                              'Lewati',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ── Download progress ────────────────────────────────────────────
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_download_outlined,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _progress >= 1.0
                                ? 'Data berhasil diunduh'
                                : 'Mengunduh data: $_statusLabel',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 5,
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.12),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Data tersimpan di perangkat untuk akses offline',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
