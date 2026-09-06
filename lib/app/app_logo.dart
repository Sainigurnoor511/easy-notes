import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// The Easy Notes mark: two stacked, tilted note cards with two rule lines.
///
/// Drawn as a vector so it stays crisp at any size and carries no background of
/// its own — it sits directly on whatever surface hosts it. The whole mark is
/// derived from a single colour (`primary` by default); the back card and the
/// short rule take that colour at [_mutedAlpha] to preserve the original
/// artwork's two-tone depth without introducing a second hue.
///
/// Where the front card overlaps the back one, the back card's stroke is
/// punched out rather than covered with an opaque fill, so the mark reads
/// correctly on a tinted surface as well as on the canvas.
class AppLogo extends StatelessWidget {
  final double size;

  /// Defaults to the theme's `primary`.
  final Color? color;

  const AppLogo({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.palette.primary;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _AppLogoPainter(tint)),
      ),
    );
  }
}

/// Geometry is expressed in a 100×100 design space and scaled to the widget.
class _AppLogoPainter extends CustomPainter {
  final Color color;

  const _AppLogoPainter(this.color);

  /// The back card and the short rule sit at this alpha, matching the original
  /// mark's lighter second tone.
  static const double _mutedAlpha = 0.45;

  static const double _cardSide = 56;
  static const double _cardRadius = 15;
  static const double _stroke = 5.5;
  static const Offset _frontCentre = Offset(58, 42);
  static const Offset _backCentre = Offset(42, 58);

  /// Both cards lean the same way, so the stack reads as one object.
  static const double _tilt = 12 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    if (s <= 0) return;

    final stroke = _stroke * s;
    final strong = color;
    final muted = color.withValues(alpha: _mutedAlpha);

    Paint linePaint(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c
      ..isAntiAlias = true;

    RRect cardRect(double inflate) => RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: _cardSide * s + inflate * 2,
            height: _cardSide * s + inflate * 2,
          ),
          Radius.circular(_cardRadius * s + inflate),
        );

    void inCardFrame(Offset centre, VoidCallback draw) {
      canvas.save();
      canvas.translate(centre.dx * s, centre.dy * s);
      canvas.rotate(_tilt);
      draw();
      canvas.restore();
    }

    // One layer, so the punch-out below only clears the mark's own pixels.
    canvas.saveLayer(Offset.zero & size, Paint());

    inCardFrame(_backCentre, () {
      canvas.drawRRect(cardRect(0), linePaint(muted));
    });

    // Hide the back card where the front card sits, up to its outer edge.
    inCardFrame(_frontCentre, () {
      canvas.drawRRect(
        cardRect(stroke / 2),
        Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.clear
          ..isAntiAlias = true,
      );
    });

    inCardFrame(_frontCentre, () {
      canvas.drawRRect(cardRect(0), linePaint(strong));

      // Two rules, left-aligned, the lower one shorter.
      final long = linePaint(strong);
      final short = linePaint(muted);
      canvas.drawLine(Offset(-15 * s, 1 * s), Offset(9 * s, 1 * s), long);
      canvas.drawLine(Offset(-15 * s, 14 * s), Offset(-2 * s, 14 * s), short);
    });

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AppLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
