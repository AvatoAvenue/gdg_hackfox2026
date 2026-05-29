import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppLogo
//
// Concept: a dynamic wheelchair-user figure standing on a curved accessible
// route, inside a teal gradient circle.  The raised arm conveys momentum and
// empowerment; the dashed route arc with a destination pin ties the mark to
// "safe routes".
//
// Usage:
//   AppLogo(size: 48)                          // full-color (hero, splash)
//   AppLogo(size: 36, tint: Color(0xFFA0D3CD)) // monochrome on dark surfaces
//
// When [tint] is provided the gradient background and route arc are omitted —
// only the figure silhouette is drawn in the given colour.  Ideal for placing
// the logo on coloured bars (e.g. the dark navy top bar).
//
// ─── ALTERNATIVE: load your own vector file ──────────────────────────────────
// If you later want to swap in a professionally designed SVG instead:
//
//   1. flutter_svg is already in pubspec.yaml.
//   2. Drop your file at assets/images/logo.svg and register the folder.
//   3. Replace the AppLogo body with:
//
//      import 'package:flutter_svg/flutter_svg.dart';
//
//      class AppLogo extends StatelessWidget {
//        final double size;
//        final Color? tint;          // maps to SvgPicture colorFilter
//        const AppLogo({super.key, this.size = 48, this.tint});
//
//        @override
//        Widget build(BuildContext context) {
//          return SvgPicture.asset(
//            'assets/images/logo.svg',
//            width: size,
//            height: size,
//            colorFilter: tint == null
//                ? null
//                : ColorFilter.mode(tint!, BlendMode.srcIn),
//          );
//        }
//      }
// ─────────────────────────────────────────────────────────────────────────────

class AppLogo extends StatelessWidget {
  final double size;

  /// When set, the background circle is hidden and the figure is drawn in this
  /// colour. Use for placing the logo on non-white / coloured surfaces.
  final Color? tint;

  const AppLogo({super.key, this.size = 48, this.tint});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LogoPainter(tint: tint)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter — all coordinates are fractions of [s] (= size.width) for clean
// scaling from 32 px to 512 px.
// ─────────────────────────────────────────────────────────────────────────────
class _LogoPainter extends CustomPainter {
  final Color? tint;
  const _LogoPainter({this.tint});

  bool get _mono => tint != null;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s / 2;

    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: s / 2)),
    );

    // ── Background (full-colour mode only) ────────────────────────────────
    if (!_mono) {
      final bgPaint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.30),
          radius: 1.0,
          colors: [Color(0xFF289F91), Color(0xFF1C7269)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s / 2));
      canvas.drawCircle(Offset(cx, cy), s / 2, bgPaint);

      // Subtle depth ring
      canvas.drawCircle(
        Offset(cx, cy),
        s * 0.455,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.016,
      );
    }

    // ── Figure ────────────────────────────────────────────────────────────
    final figureColor = tint ?? Colors.white;
    final strokeW = s * 0.068;

    Paint fig([double? w]) => Paint()
      ..color = figureColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w ?? strokeW;

    // Head
    canvas.drawCircle(
      Offset(s * 0.50, s * 0.200),
      s * 0.082,
      Paint()..color = figureColor,
    );

    // Torso (forward lean)
    canvas.drawLine(Offset(s * 0.500, s * 0.285), Offset(s * 0.455, s * 0.510), fig());

    // Left arm — raised forward (momentum / empowerment)
    canvas.drawLine(Offset(s * 0.490, s * 0.370), Offset(s * 0.300, s * 0.265), fig());

    // Right arm — extended back/down (push)
    canvas.drawLine(Offset(s * 0.490, s * 0.370), Offset(s * 0.670, s * 0.440), fig());

    // Seat (horizontal bar)
    canvas.drawLine(Offset(s * 0.455, s * 0.510), Offset(s * 0.635, s * 0.510), fig());

    // Large rear wheel
    canvas.drawCircle(Offset(s * 0.440, s * 0.665), s * 0.138, fig(strokeW * 0.95));

    // Small front wheel
    canvas.drawCircle(Offset(s * 0.670, s * 0.705), s * 0.048, fig(strokeW * 0.75));

    // ── Route arc & pin (full-colour mode only — too fine at small sizes) ─
    if (!_mono) {
      const routeColor = Color(0xFFA0D3CD);

      final routePaint = Paint()
        ..color = routeColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.048;

      canvas.drawCircle(
        Offset(s * 0.175, s * 0.855),
        s * 0.038,
        Paint()..color = routeColor,
      );

      final routePath = Path()
        ..moveTo(s * 0.175, s * 0.855)
        ..cubicTo(
          s * 0.340, s * 0.800,
          s * 0.620, s * 0.800,
          s * 0.825, s * 0.855,
        );
      _drawDashed(canvas, routePath, routePaint, s * 0.042, s * 0.028);
      _drawPin(canvas, Offset(s * 0.825, s * 0.845), s * 0.055, routeColor);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint, double dashLen, double gapLen) {
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      bool drawing = true;
      while (dist < metric.length) {
        final segLen = drawing ? dashLen : gapLen;
        if (drawing) {
          canvas.drawPath(
            metric.extractPath(dist, math.min(dist + segLen, metric.length)),
            paint,
          );
        }
        dist += segLen;
        drawing = !drawing;
      }
    }
  }

  // [tip] = bottom point of the pin; [r] = radius of the pin head circle.
  void _drawPin(Canvas canvas, Offset tip, double r, Color color) {
    final paint = Paint()..color = color;
    final headCenter = Offset(tip.dx, tip.dy - r * 1.15);

    canvas.drawCircle(headCenter, r, paint);

    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - r * 0.62, tip.dy - r * 0.88)
        ..lineTo(tip.dx + r * 0.62, tip.dy - r * 0.88)
        ..close(),
      paint,
    );

    // White inner dot (map-pin convention)
    canvas.drawCircle(headCenter, r * 0.42, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.tint != tint;
}
