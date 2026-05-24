import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:grove/models/grove_models.dart';
import 'package:grove/theme/grove_theme.dart';

class FractalTreePainter extends CustomPainter {
  final GrowthStage  stage;
  final Color        baseColor;
  final double       progress;
  final double       windPhase;
  final int          daysElapsed;
  final int          geneticSeed;
  final GrowthStage? shadowStage;

  const FractalTreePainter({
    required this.stage,
    required this.baseColor,
    required this.progress,
    this.windPhase    = 0,
    this.daysElapsed  = 0,
    this.geneticSeed  = 0,
    this.shadowStage,
  });

  int get _maxDepth {
    switch (stage) {
      case GrowthStage.seed:      return 0;
      case GrowthStage.sprout:    return 2;
      case GrowthStage.sapling:   return 3;
      case GrowthStage.youngTree: return 4;
      case GrowthStage.groveTree: return 5;
    }
  }

  int get _shadowDepth {
    if (shadowStage == null) return 0;
    switch (shadowStage!) {
      case GrowthStage.seed:      return 0;
      case GrowthStage.sprout:    return 2;
      case GrowthStage.sapling:   return 3;
      case GrowthStage.youngTree: return 4;
      case GrowthStage.groveTree: return 5;
    }
  }

  double get _leafDensity {
    if (daysElapsed <= 20) return 0.0;
    if (daysElapsed <= 50) return ((daysElapsed - 20) / 30.0).clamp(0.0, 1.0);
    return 1.0;
  }

  Color get _activeColor => baseColor;

  Color get _barkColor {
    final hsl = HSLColor.fromColor(_activeColor);
    return hsl.withLightness((hsl.lightness * 0.45).clamp(0.0, 1.0))
    .withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0))
    .toColor();
  }

  Color get _leafColor {
    final hsl = HSLColor.fromColor(_activeColor);
    return hsl.withLightness((hsl.lightness * 1.15).clamp(0.0, 1.0))
    .withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0))
    .toColor();
  }

  Color get _leafHighlight {
    final hsl = HSLColor.fromColor(_activeColor);
    return hsl.withLightness((hsl.lightness * 1.40).clamp(0.0, 1.0))
    .withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0))
    .toColor();
  }

  double _genetic(String key) {
    final hash = ((geneticSeed.abs() + key.hashCode.abs()) % 1000);
    return (hash / 1000.0) * 0.2 - 0.1;
  }

  double _geneticPositive(String key, {double scale = 1.0}) {
    final hash = ((geneticSeed.abs() + key.hashCode.abs()) % 1000);
    return (hash / 1000.0) * scale;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (stage == GrowthStage.groveTree || (stage == GrowthStage.youngTree && progress > 0.6)) {
      _drawAmbientSpores(canvas, size);
    }
    if (shadowStage != null && _shadowDepth > _maxDepth) {
      _drawTree(canvas: canvas, size: size,
                color: GroveTheme.slateGrey.withValues(alpha: 0.08), maxDepth: _shadowDepth, isShadow: true);
    }
    if (stage == GrowthStage.seed) { _drawSeed(canvas, size); return; }
    _drawTree(canvas: canvas, size: size, color: _activeColor, maxDepth: _maxDepth, isShadow: false);
  }

  void _drawAmbientSpores(Canvas canvas, Size size) {
    final sporeCount = 8 + (geneticSeed.abs() % 8);
    final paint      = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < sporeCount; i++) {
      final seedOffset = ((geneticSeed.abs() + i * 53) % 100);
      final speed      = 0.4 + (seedOffset % 6) * 0.18;
      final basePhase  = (windPhase * speed + seedOffset * 0.063) % (math.pi * 2);
      final rawY       = (1.0 - basePhase / (math.pi * 2)) * size.height;
      final xDrift     = math.sin(basePhase * 1.7 + seedOffset * 0.1) * 22.0;
      final x          = size.width * 0.15 + (seedOffset / 100.0) * size.width * 0.7 + xDrift;
      final fadeY      = math.sin((rawY / size.height).clamp(0.0, 1.0) * math.pi);
      final opacity    = (0.35 * fadeY).clamp(0.0, 1.0);
      final radius     = 1.2 + (seedOffset % 3) * 0.5;
      paint.color = GroveTheme.goldenLich.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, rawY), radius, paint);
      paint.color = GroveTheme.goldenLich.withValues(alpha: opacity * 0.3);
      canvas.drawCircle(Offset(x, rawY), radius * 2.5, paint);
    }
  }

  void _drawTree({required Canvas canvas, required Size size,
    required Color color, required int maxDepth, required bool isShadow}) {
    final gx       = size.width  * 0.5;
    final gy       = size.height * 0.93;
    final trunkLen = size.height * _lerpD(0.28, 0.44, progress);
    final spread   = _lerpD(0.30, 0.52, progress) * (1.0 + _genetic('spread'));
    final lenRatio = _lerpD(0.66, 0.73, progress) * (1.0 + _genetic('ratio'));
    final trunkW   = _lerpD(5.0, 9.0, progress);

    if (!isShadow && maxDepth >= 2) {
      _drawRootFlare(canvas, Offset(gx, gy), trunkW, color);
    }
    _drawBranch(
      canvas: canvas, start: Offset(gx, gy),
      angle: -math.pi / 2, length: trunkLen, depth: maxDepth, maxDepth: maxDepth,
      spreadAngle: spread, lengthRatio: lenRatio, strokeWidth: trunkW,
      depthFromTip: maxDepth, color: color, isShadow: isShadow, isMainTrunk: true,
    );
    }

    void _drawRootFlare(Canvas canvas, Offset base, double trunkWidth, Color color) {
      final barkC  = _barkColor;
      final flareR = trunkWidth * 1.8;
      canvas.drawOval(
        Rect.fromCenter(center: base.translate(0, 3), width: flareR * 3.2, height: flareR * 0.9),
        Paint()..color = Colors.black.withValues(alpha: 0.18)..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawOval(
        Rect.fromCenter(center: base, width: flareR * 2.4, height: flareR * 1.1),
        Paint()..color = barkC.withValues(alpha: 0.85)..style = PaintingStyle.fill,
      );
      final linePaint = Paint()..color = _activeColor.withValues(alpha: 0.25)..strokeWidth = 0.8
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      for (int i = 0; i < 3; i++) {
        final ox = (i - 1) * flareR * 0.55;
        canvas.drawLine(Offset(base.dx + ox, base.dy - flareR * 0.2),
        Offset(base.dx + ox * 1.4, base.dy + flareR * 0.3), linePaint);
      }
    }

    void _drawBranch({
      required Canvas canvas, required Offset start,
      required double angle, required double length,
      required int depth, required int maxDepth,
      required double spreadAngle, required double lengthRatio,
      required double strokeWidth, required int depthFromTip,
      required Color color, required bool isShadow, bool isMainTrunk = false,
    }) {
      double windOffset = 0;
      if (!isShadow && depthFromTip <= 3 && windPhase > 0) {
        final windStrength = (1.0 - depthFromTip / 4.0) * 0.045;
        windOffset = math.sin(windPhase + depthFromTip * 0.9 + _genetic('wind') * math.pi) * windStrength;
      }
      final adjustedAngle = angle + windOffset + _genetic('angle_$depth') * 0.13;
      final tip = Offset(
        start.dx + length * math.cos(adjustedAngle),
        start.dy + length * math.sin(adjustedAngle),
      );
      final depthRatio    = maxDepth > 0 ? depth / maxDepth : 1.0;
      final branchOpacity = _lerpD(0.60, 0.98, depthRatio);
      final barkC         = _barkColor;

      if (!isShadow) {
        if (strokeWidth > 1.5) {
          canvas.drawLine(start, tip, Paint()
          ..color = barkC.withValues(alpha: branchOpacity * 0.55)
          ..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
          canvas.drawLine(start, tip, Paint()
          ..color = color.withValues(alpha: branchOpacity * 0.80)
          ..strokeWidth = strokeWidth * 0.70..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
          canvas.drawLine(
            start.translate(math.cos(adjustedAngle + math.pi / 2) * strokeWidth * 0.18,
            math.sin(adjustedAngle + math.pi / 2) * strokeWidth * 0.18),
            tip.translate(  math.cos(adjustedAngle + math.pi / 2) * strokeWidth * 0.10,
            math.sin(adjustedAngle + math.pi / 2) * strokeWidth * 0.10),
            Paint()..color = color.withValues(alpha: branchOpacity * 0.35)
            ..strokeWidth = strokeWidth * 0.22..strokeCap = StrokeCap.round..style = PaintingStyle.stroke,
          );
          if (strokeWidth > 3.5) _drawBarkNicks(canvas, start, tip, strokeWidth, color, branchOpacity);
        } else {
          canvas.drawLine(start, tip, Paint()
          ..color = color.withValues(alpha: branchOpacity)
          ..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
        }
      } else {
        canvas.drawLine(start, tip, Paint()
        ..color = color.withValues(alpha: branchOpacity)
        ..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
      }

      if (depth == 0) {
        if (!isShadow) _drawLeafCluster(canvas, tip, length, adjustedAngle, color);
        return;
      }

      final childLen   = length * lengthRatio * (1.0 + _genetic('len_$depth') * 0.5);
      final childWidth = strokeWidth * 0.62;
      final asym       = 0.04 + _genetic('asym') * 0.025;

      _drawBranch(canvas: canvas, start: tip, angle: adjustedAngle - spreadAngle,
                  length: childLen * (1.0 - asym), depth: depth - 1, maxDepth: maxDepth,
                  spreadAngle: spreadAngle * 0.90, lengthRatio: lengthRatio, strokeWidth: childWidth,
                  depthFromTip: depthFromTip - 1, color: color, isShadow: isShadow);
      _drawBranch(canvas: canvas, start: tip, angle: adjustedAngle + spreadAngle,
                  length: childLen * (1.0 + asym), depth: depth - 1, maxDepth: maxDepth,
                  spreadAngle: spreadAngle * 0.90, lengthRatio: lengthRatio, strokeWidth: childWidth,
                  depthFromTip: depthFromTip - 1, color: color, isShadow: isShadow);

      if (maxDepth >= 4 && depth == maxDepth - 1) {
        _drawBranch(canvas: canvas, start: tip, angle: adjustedAngle + _genetic('mid_$depth') * 0.3,
        length: childLen * 0.75, depth: depth - 2, maxDepth: maxDepth,
        spreadAngle: spreadAngle * 0.82, lengthRatio: lengthRatio, strokeWidth: childWidth * 0.75,
        depthFromTip: depthFromTip - 2, color: color, isShadow: isShadow);
      }
    }

    void _drawBarkNicks(Canvas canvas, Offset start, Offset tip,
                        double strokeWidth, Color color, double opacity) {
      final nickCount = 2 + (strokeWidth / 3).floor();
      final nickPaint = Paint()
      ..color = _barkColor.withValues(alpha: opacity * 0.45)
      ..strokeWidth = 0.7..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      final dx = tip.dx - start.dx; final dy = tip.dy - start.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1) return;
      final nx = -dy / len; final ny = dx / len;
      for (int k = 1; k <= nickCount; k++) {
        final t = k / (nickCount + 1.0);
        final px = start.dx + dx * t; final py = start.dy + dy * t;
        final half = strokeWidth * 0.30 * (0.7 + _geneticPositive('nick_$k'));
        canvas.drawLine(Offset(px + nx * half, py + ny * half), Offset(px - nx * half, py - ny * half), nickPaint);
      }
                        }

                        void _drawLeafCluster(Canvas canvas, Offset tip, double branchLength,
                                              double branchAngle, Color color) {
                          if (_leafDensity <= 0 && daysElapsed < 8) return;
                          final lc   = _leafColor; final lh = _leafHighlight;
                          final base = branchLength * 0.50;
                          final leafCount = 3 + (_leafDensity * 5).floor();
                          final rng       = math.Random(geneticSeed + tip.dx.toInt() + tip.dy.toInt());
                          for (int i = 0; i < leafCount; i++) {
                            final angleOff  = (rng.nextDouble() - 0.5) * 2.2;
                            final distOff   = rng.nextDouble() * base * 0.75;
                            final leafAngle = branchAngle + angleOff;
                            final lx = tip.dx + math.cos(leafAngle) * distOff;
                            final ly = tip.dy + math.sin(leafAngle) * distOff;
                            final stageSizeBoost = switch (stage) {
                              GrowthStage.sprout    => 0.55,
                              GrowthStage.sapling   => 0.40,
                              GrowthStage.youngTree => 0.22,
                              GrowthStage.groveTree => 0.10,
                              _                     => 0.30,
                            };
                            final leafSize  = base * (stageSizeBoost + rng.nextDouble() * 0.26 + _leafDensity * 0.12);
                            final rotation  = branchAngle + angleOff * 0.6 + rng.nextDouble() * 0.4;
                            final distFactor = 1.0 - (distOff / (base * 0.75)).clamp(0.0, 0.5);
                            final leafOpacity = (0.55 + _leafDensity * 0.35) * distFactor;
                            _drawSingleLeaf(canvas, Offset(lx, ly), leafSize, rotation, lc, lh, leafOpacity);
                          }
                          if (_leafDensity > 0.55) _drawLeafFlecks(canvas, tip, base, color);
                                              }

                                              void _drawSingleLeaf(Canvas canvas, Offset center, double size, double angle,
                                                                   Color leafCol, Color highlight, double opacity) {
                                                canvas.save();
                                                canvas.translate(center.dx, center.dy);
                                                canvas.rotate(angle);

                                                final leafPath = Path();
                                                leafPath.moveTo(0, -size);
                                                leafPath.cubicTo(size * 0.55, -size * 0.55, size * 0.62, size * 0.35, 0, size * 0.45);
                                                leafPath.cubicTo(-size * 0.62, size * 0.35, -size * 0.55, -size * 0.55, 0, -size);
                                                leafPath.close();

                                                canvas.drawPath(leafPath, Paint()..color = leafCol.withValues(alpha: opacity)..style = PaintingStyle.fill);

                                                final highlightPath = Path();
                                                highlightPath.moveTo(0, -size);
                                                highlightPath.cubicTo(size * 0.28, -size * 0.55, size * 0.22, -size * 0.05, 0, -size * 0.05);
                                                highlightPath.cubicTo(-size * 0.22, -size * 0.05, -size * 0.28, -size * 0.55, 0, -size);
                                                highlightPath.close();
                                                canvas.drawPath(highlightPath, Paint()..color = highlight.withValues(alpha: opacity * 0.28)..style = PaintingStyle.fill);

                                                canvas.drawLine(Offset(0, -size * 0.85), Offset(0, size * 0.35),
                                                Paint()..color = leafCol.withValues(alpha: opacity * 0.55)..strokeWidth = size * 0.07
                                                ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);

                                                final veinPaint = Paint()..color = leafCol.withValues(alpha: opacity * 0.30)
                                                ..strokeWidth = size * 0.04..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
                                                for (final veinT in [0.25, 0.55]) {
                                                  final vy = -size * (0.85 - veinT * 1.2); final vx = size * 0.42 * veinT;
                                                  canvas.drawLine(Offset(0, vy), Offset( vx, vy + size * 0.18), veinPaint);
                                                  canvas.drawLine(Offset(0, vy), Offset(-vx, vy + size * 0.18), veinPaint);
                                                }
                                                canvas.drawPath(leafPath, Paint()..color = leafCol.withValues(alpha: opacity * 0.40)
                                                ..strokeWidth = size * 0.055..style = PaintingStyle.stroke);
                                                canvas.restore();
                                                                   }

                                                                   void _drawLeafFlecks(Canvas canvas, Offset tip, double radius, Color color) {
                                                                     final fleckCount = (3 + _leafDensity * 4).floor();
                                                                     final paint      = Paint()..style = PaintingStyle.fill;
                                                                     final rng        = math.Random(geneticSeed + tip.dx.toInt() * 7);
                                                                     for (int i = 0; i < fleckCount; i++) {
                                                                       final a = rng.nextDouble() * math.pi * 2; final d = rng.nextDouble() * radius * 0.85;
                                                                       final fx = tip.dx + math.cos(a) * d; final fy = tip.dy + math.sin(a) * d;
                                                                       final fr = 1.0 + rng.nextDouble() * 1.2;
                                                                       paint.color = GroveTheme.goldenLich.withValues(alpha: 0.50 + _leafDensity * 0.35);
                                                                       canvas.drawCircle(Offset(fx, fy), fr, paint);
                                                                     }
                                                                   }

                                                                   void _drawSeed(Canvas canvas, Size size) {
                                                                     final cx = size.width * 0.5; final cy = size.height * 0.68;
                                                                     final r  = size.width * 0.13 * (0.35 + progress * 0.65);
                                                                     final ac = _activeColor; final bc = _barkColor;

                                                                     canvas.drawOval(
                                                                       Rect.fromCenter(center: Offset(cx, cy + r * 0.65), width: r * 3.0, height: r * 0.7),
                                                                       Paint()..color = Colors.black.withValues(alpha: 0.15)..style = PaintingStyle.fill
                                                                       ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
                                                                     );

                                                                     final seedPath = Path();
                                                                     seedPath.moveTo(cx, cy - r * 0.95);
                                                                     seedPath.cubicTo(cx + r * 0.85, cy - r * 0.55, cx + r * 0.90, cy + r * 0.40, cx, cy + r * 0.60);
                                                                     seedPath.cubicTo(cx - r * 0.90, cy + r * 0.40, cx - r * 0.85, cy - r * 0.55, cx, cy - r * 0.95);
                                                                     seedPath.close();

                                                                     canvas.drawPath(seedPath, Paint()..color = ac.withValues(alpha: 0.75)..style = PaintingStyle.fill);

                                                                     final sheenPath = Path();
                                                                     sheenPath.moveTo(cx, cy - r * 0.90);
                                                                     sheenPath.cubicTo(cx + r * 0.30, cy - r * 0.70, cx + r * 0.28, cy - r * 0.10, cx, cy - r * 0.05);
                                                                     sheenPath.cubicTo(cx - r * 0.28, cy - r * 0.10, cx - r * 0.30, cy - r * 0.70, cx, cy - r * 0.90);
                                                                     sheenPath.close();
                                                                     canvas.drawPath(sheenPath, Paint()..color = ac.withValues(alpha: 0.30)..style = PaintingStyle.fill);

                                                                     canvas.drawPath(seedPath, Paint()..color = bc.withValues(alpha: 0.70)..strokeWidth = r * 0.10..style = PaintingStyle.stroke);
                                                                     canvas.drawLine(Offset(cx, cy - r * 0.80), Offset(cx, cy + r * 0.50),
                                                                     Paint()..color = bc.withValues(alpha: 0.50)..strokeWidth = r * 0.06..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);

                                                                     if (progress > 0.2) {
                                                                       final rootOpacity = ((progress - 0.2) / 0.8).clamp(0.0, 0.5);
                                                                       final rootPaint   = Paint()..color = bc.withValues(alpha: rootOpacity)..strokeWidth = r * 0.09
                                                                       ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
                                                                       for (int i = 0; i < 4; i++) {
                                                                         final baseAngle = (math.pi * 0.15) + (i - 1.5) * 0.45;
                                                                         final rootLen   = r * (0.55 + progress * 0.55 + _genetic('root_$i') * 0.2);
                                                                         final midX = cx + math.cos(math.pi / 2 + baseAngle * 0.4) * r * 0.3;
                                                                         final midY = cy + r * 0.55 + r * 0.3;
                                                                         final endX = cx + math.cos(math.pi / 2 + baseAngle) * rootLen;
                                                                         final endY = cy + r * 0.55 + rootLen * 0.65;
                                                                         final rootPath = Path()..moveTo(cx, cy + r * 0.55)..quadraticBezierTo(midX, midY, endX, endY);
                                                                         canvas.drawPath(rootPath, rootPaint);
                                                                       }
                                                                     }

                                                                     if (progress > 0.3) {
                                                                       final sproutH  = size.height * 0.22 * ((progress - 0.3) / 0.7);
                                                                       final sproutY0 = cy - r * 0.90;
                                                                       final sproutY1 = sproutY0 - sproutH;
                                                                       final stemPath = Path()..moveTo(cx, sproutY0)
                                                                       ..quadraticBezierTo(cx + r * 0.18, sproutY0 - sproutH * 0.5, cx, sproutY1);
                                                                       canvas.drawPath(stemPath, Paint()..color = ac.withValues(alpha: 0.85)..strokeWidth = r * 0.14
                                                                       ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
                                                                       if (progress > 0.5) {
                                                                         final leafGrow = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
                                                                         final leafSz   = r * 0.45 * leafGrow;
                                                                         _drawSingleLeaf(canvas, Offset(cx - leafSz * 0.8, sproutY1 + leafSz * 0.3),
                                                                         leafSz, -math.pi * 0.35, _leafColor, _leafHighlight, 0.80 * leafGrow);
                                                                         _drawSingleLeaf(canvas, Offset(cx + leafSz * 0.8, sproutY1 + leafSz * 0.3),
                                                                         leafSz,  math.pi * 0.35, _leafColor, _leafHighlight, 0.80 * leafGrow);
                                                                       }
                                                                     }
                                                                   }

                                                                   static double _lerpD(double a, double b, double t) => a + (b - a) * t;

                                                                   @override
                                                                   bool shouldRepaint(FractalTreePainter old) =>
                                                                   old.stage       != stage       || old.baseColor != baseColor ||
                                                                   old.progress    != progress    || old.windPhase != windPhase ||
                                                                   old.daysElapsed != daysElapsed || old.geneticSeed != geneticSeed ||
                                                                   old.shadowStage != shadowStage;
}
