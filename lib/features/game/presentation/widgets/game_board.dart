import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../domain/entities/game_entities.dart';

typedef ArrowTapCallback = void Function(String arrowId);

class GameBoard extends StatelessWidget {
  const GameBoard({
    super.key,
    required this.rows,
    required this.cols,
    required this.arrows,
    required this.arrowColors,
    required this.onArrowTapped,
    this.hintArrowId,
    this.failedArrowId,
    this.removedArrowId,
    this.exitProgress = 0,
    this.hintPulse = 0,
    this.enabled = true,
  });

  final int rows;
  final int cols;
  final List<ArrowEntity> arrows;
  final List<Color> arrowColors;
  final ArrowTapCallback onArrowTapped;
  final String? hintArrowId;
  final String? failedArrowId;
  final String? removedArrowId;
  final double exitProgress;
  final double hintPulse;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final aspect = cols / rows;
        var width = maxW;
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }
        if (width < maxW && height < maxH) {
          final byH = maxH;
          final byW = byH * aspect;
          if (byW <= maxW) {
            height = byH;
            width = byW;
          }
        }

        final size = Size(width, height);

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: RepaintBoundary(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: enabled
                    ? (event) {
                        final id = hitTestArrow(
                          event.localPosition,
                          size,
                          rows: rows,
                          cols: cols,
                          arrows: arrows,
                        );
                        if (id != null) onArrowTapped(id);
                      }
                    : null,
                child: CustomPaint(
                  isComplex: true,
                  willChange: hintArrowId != null || exitProgress > 0,
                  painter: BoardPainter(
                    rows: rows,
                    cols: cols,
                    arrows: arrows,
                    arrowColors: arrowColors,
                    hintArrowId: hintArrowId,
                    failedArrowId: failedArrowId,
                    removedArrowId: removedArrowId,
                    exitProgress: exitProgress,
                    hintPulse: hintPulse,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Public for tests — generous finger-friendly hit along path segments.
  static String? hitTestArrow(
    Offset pos,
    Size boardSize, {
    required int rows,
    required int cols,
    required List<ArrowEntity> arrows,
  }) {
    if (arrows.isEmpty) return null;
    final cellW = boardSize.width / cols;
    final cellH = boardSize.height / rows;
    // Finger pad ~22–36px: previously 0.55*cell on 32-col boards was ~5px.
    final threshold = math.max(22.0, math.min(cellW, cellH) * 1.15);

    String? best;
    var bestDist = threshold;

    for (final arrow in arrows) {
      if (arrow.path.isEmpty) continue;
      final pts = [
        for (final c in arrow.path)
          Offset((c.col + 0.5) * cellW, (c.row + 0.5) * cellH),
      ];
      // Fat tip hit so heads are easy to tap.
      final tip = pts.last;
      final tipDist = (pos - tip).distance;
      if (tipDist < bestDist) {
        bestDist = tipDist;
        best = arrow.id;
      }
      for (var i = 0; i < pts.length; i++) {
        final d = (pos - pts[i]).distance;
        if (d < bestDist) {
          bestDist = d;
          best = arrow.id;
        }
        if (i + 1 < pts.length) {
          final seg = _distToSegment(pos, pts[i], pts[i + 1]);
          if (seg < bestDist) {
            bestDist = seg;
            best = arrow.id;
          }
        }
      }
    }
    return best;
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 0.0001) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.rows,
    required this.cols,
    required this.arrows,
    required this.arrowColors,
    required this.hintArrowId,
    required this.failedArrowId,
    required this.removedArrowId,
    required this.exitProgress,
    this.hintPulse = 0,
  });

  final int rows;
  final int cols;
  final List<ArrowEntity> arrows;
  final List<Color> arrowColors;
  final String? hintArrowId;
  final String? failedArrowId;
  final String? removedArrowId;
  final double exitProgress;
  final double hintPulse;

  double _stroke(double cellW, double cellH) =>
      (math.min(cellW, cellH) * 0.14).clamp(2.4, 5.5);

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final dense = arrows.length >= 36;

    for (final arrow in arrows) {
      _paintArrow(canvas, arrow, cellW, cellH, dense: dense);
    }
  }

  Offset _cellCenter(Cell c, double cellW, double cellH) =>
      Offset((c.col + 0.5) * cellW, (c.row + 0.5) * cellH);

  List<Offset> _buildRail(ArrowEntity arrow, double cellW, double cellH) {
    final rail = [
      for (final c in arrow.path) _cellCenter(c, cellW, cellH),
    ];
    final (dr, dc) = arrow.tipDirection.delta;
    final extend = arrow.path.length + math.max(rows, cols) + 3;
    var tip = rail.last;
    for (var i = 0; i < extend; i++) {
      tip = Offset(tip.dx + dc * cellW, tip.dy + dr * cellH);
      rail.add(tip);
    }
    return rail;
  }

  Offset _sampleRail(List<Offset> rail, double index) {
    if (rail.isEmpty) return Offset.zero;
    if (index <= 0) return rail.first;
    if (index >= rail.length - 1) {
      final last = rail.length - 1;
      final overflow = index - last;
      final dir = last == 0 ? Offset.zero : rail[last] - rail[last - 1];
      return rail[last] + dir * overflow;
    }
    final i = index.floor();
    final t = index - i;
    return Offset.lerp(rail[i], rail[i + 1], t)!;
  }

  List<Offset> _slidingPoints(
    ArrowEntity arrow,
    double cellW,
    double cellH,
    double travel,
  ) {
    final rail = _buildRail(arrow, cellW, cellH);
    return [
      for (var i = 0; i < arrow.path.length; i++)
        _sampleRail(rail, i + travel),
    ];
  }

  Path _smoothPath(List<Offset> points, double radius) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.addOval(Rect.fromCircle(center: points.first, radius: 1));
      return path;
    }
    if (points.length == 2) {
      path.moveTo(points[0].dx, points[0].dy);
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];
      final toPrev = prev - curr;
      final toNext = next - curr;
      final dPrev = toPrev.distance;
      final dNext = toNext.distance;
      if (dPrev < 0.001 || dNext < 0.001) {
        path.lineTo(curr.dx, curr.dy);
        continue;
      }
      final r = math.min(radius, math.min(dPrev, dNext) * 0.45);
      final p1 = curr + toPrev / dPrev * r;
      final p2 = curr + toNext / dNext * r;
      path.lineTo(p1.dx, p1.dy);
      path.quadraticBezierTo(curr.dx, curr.dy, p2.dx, p2.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  void _paintArrow(
    Canvas canvas,
    ArrowEntity arrow,
    double cellW,
    double cellH, {
    required bool dense,
  }) {
    final color = arrowColors[arrow.colorIndex % arrowColors.length];
    final isHint = arrow.id == hintArrowId;
    final isFailed = arrow.id == failedArrowId;
    final isExiting = arrow.id == removedArrowId && exitProgress > 0;
    final stroke = _stroke(cellW, cellH);
    final tipDir = arrow.tipDirection;

    final travel = isExiting
        ? exitProgress * (arrow.path.length + math.max(rows, cols) + 2)
        : 0.0;
    final points = isExiting
        ? _slidingPoints(arrow, cellW, cellH, travel)
        : [for (final c in arrow.path) _cellCenter(c, cellW, cellH)];

    if (points.isEmpty) return;

    final opacity =
        isExiting ? (1.0 - exitProgress * 0.25).clamp(0.4, 1.0) : 1.0;
    final path = _smoothPath(points, math.min(cellW, cellH) * 0.28);
    final strokeColor =
        (isFailed ? const Color(0xFFFF3B3B) : color).withValues(alpha: opacity);

    final linePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = !dense;

    if (isHint && !isExiting) {
      // Cheap pulse — no MaskFilter.blur (was a major FPS killer).
      final beat = 0.5 + 0.5 * math.sin(hintPulse * math.pi * 2);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.35 + beat * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * (2.0 + beat * 1.6)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Skip soft shadows on dense boards (GPU thrash).
    if (!dense) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.05 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
      );
    }

    canvas.drawPath(path, linePaint);

    final (dr, dc) = tipDir.delta;
    final head = points.last;
    Offset heading;
    if (isExiting && points.length >= 2) {
      final seg = points.last - points[points.length - 2];
      heading = seg.distance > 0.001
          ? seg
          : Offset(dc * cellW, dr * cellH);
    } else {
      heading = Offset(dc * cellW, dr * cellH);
    }

    final dist = heading.distance;
    if (dist < 0.001) return;
    final nx = heading.dx / dist;
    final ny = heading.dy / dist;
    final headLen = stroke * 3.2;
    final headWidth = stroke * 2.4;
    final tip = Offset(head.dx + nx * headLen, head.dy + ny * headLen);
    final base =
        Offset(head.dx - nx * stroke * 0.2, head.dy - ny * stroke * 0.2);
    final left = Offset(base.dx - ny * headWidth, base.dy + nx * headWidth);
    final right = Offset(base.dx + ny * headWidth, base.dy - nx * headWidth);

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(headPath, Paint()..color = strokeColor);

    if (!isExiting || exitProgress < 0.7) {
      canvas.drawPoints(
        PointMode.points,
        [points.first],
        Paint()
          ..color = strokeColor
          ..strokeWidth = stroke * 1.3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) {
    return old.arrows != arrows ||
        old.hintArrowId != hintArrowId ||
        old.failedArrowId != failedArrowId ||
        old.removedArrowId != removedArrowId ||
        old.exitProgress != exitProgress ||
        (old.hintPulse != hintPulse && hintArrowId != null) ||
        old.arrowColors != arrowColors;
  }
}
