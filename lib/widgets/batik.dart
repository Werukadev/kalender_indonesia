import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// Kawung batik motif — four elliptical petals meeting at each grid node —
/// painted in translucent white so it works over any theme color.
class BatikKawungPainter extends CustomPainter {
  final double spacing;

  /// Multiplies the base opacities; 1 is the drawer-header look,
  /// lower reads as a subtle app-bar texture.
  final double intensity;

  const BatikKawungPainter({this.spacing = 46, this.intensity = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final petalFill = Paint()
      ..color = Colors.white.withValues(alpha: 0.07 * intensity);
    final petalStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.13 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dot = Paint()
      ..color = Colors.white.withValues(alpha: 0.16 * intensity);

    for (var y = 0.0; y <= size.height + spacing; y += spacing) {
      for (var x = 0.0; x <= size.width + spacing; x += spacing) {
        for (var i = 0; i < 4; i++) {
          final angle = math.pi / 4 + i * math.pi / 2;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(angle);
          final petal = Rect.fromCenter(
            center: Offset(spacing * 0.30, 0),
            width: spacing * 0.46,
            height: spacing * 0.22,
          );
          canvas.drawOval(petal, petalFill);
          canvas.drawOval(petal, petalStroke);
          canvas.restore();
        }
        canvas.drawCircle(Offset(x, y), 1.6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BatikKawungPainter oldDelegate) =>
      oldDelegate.spacing != spacing || oldDelegate.intensity != intensity;
}

/// Top padding needed by a scrollable that extends behind a [BatikAppBar]
/// (status bar + toolbar).
double appBarOverlayPadding(BuildContext context) =>
    MediaQuery.of(context).padding.top + kToolbarHeight;

/// Gradient used by batik headers/app bars. Very dark theme colors
/// (Midnight) get a slight lift and a shorter fade so the bar stays
/// visually distinct from dark surfaces instead of melting into them.
LinearGradient batikGradient(Color color, {double alpha = 1.0}) {
  final isVeryDark = color.computeLuminance() < 0.05;
  final begin = isVeryDark ? Color.lerp(color, Colors.white, 0.10)! : color;
  final end = Color.lerp(color, Colors.black, isVeryDark ? 0.15 : 0.28)!;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      begin.withValues(alpha: alpha),
      end.withValues(alpha: alpha),
    ],
  );
}

/// Hairline that marks the bottom edge of batik bars — keeps the boundary
/// visible even when the theme color is close to the surface behind it.
BorderSide batikEdgeSide = BorderSide(
  color: Colors.white.withValues(alpha: 0.14),
  width: 0.5,
);

/// Shared app bar: theme-colored gradient with a subtle kawung batik
/// texture, slightly translucent with a backdrop blur — content scrolling
/// beneath it (with `extendBodyBehindAppBar: true`) shows through as glass.
class BatikAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const BatikAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final color =
        context.watch<SettingsProvider>().selectedPreset.primaryColor;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      title: title,
      actions: actions,
      bottom: bottom,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              gradient: batikGradient(color, alpha: 0.92),
              border: Border(bottom: batikEdgeSide),
            ),
            child: const CustomPaint(
              painter: BatikKawungPainter(spacing: 40, intensity: 0.7),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
