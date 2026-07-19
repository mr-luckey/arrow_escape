import 'dart:math' as math;

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
  /// 0..1 heartbeat phase for hinted arrow.
  final double hintPulse;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill available play area (width AND height) — no unused margins.
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final aspect = cols / rows;
        var width = maxW;
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }
        // Prefer using full height when possible (taller phones).
        if (width < maxW && height < maxH) {
          final byH = maxH;
          final byW = byH * aspect;
          if (byW <= maxW) {
            height = byH;
            width = byW;
          }
        }

        // Edge-to-edge — no rounded clip so arrow tips meet screen sides.
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: enabled
                  ? (details) {
                      final id = _hitTest(
                        details.localPosition,
                        Size(width, height),
                      );
                      if (id != null) onArrowTapped(id);
                    }
                  : null,
              child: CustomPaint(
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
        );
      },
    );
  }

  String? _hitTest(Offset pos, Size boardSize) {
    final cellW = boardSize.width / cols;
    final cellH = boardSize.height / rows;
    // Slightly generous hit for thin strokes.
    final row = (pos.dy / cellH).floor();
    final col = (pos.dx / cellW).floor();
    if (row < 0 || col < 0 || row >= rows || col >= cols) return null;

    String? best;
    var bestDist = double.infinity;
    for (final arrow in arrows) {
      for (final c in arrow.path) {
        final center = Offset((c.col + 0.5) * cellW, (c.row + 0.5) * cellH);
        final d = (pos - center).distance;
        if (d < bestDist && d < math.min(cellW, cellH) * 0.55) {
          bestDist = d;
          best = arrow.id;
        }
      }
    }
    return best;
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

    // Clean empty playfield — no grid / no frame (screenshot style).
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0x00FFFFFF),
    );

    for (final arrow in arrows) {
      _paintArrow(canvas, arrow, cellW, cellH);
    }
  }

  Offset _cellCenter(Cell c, double cellW, double cellH) =>
      Offset((c.col + 0.5) * cellW, (c.row + 0.5) * cellH);

  List<Offset> _buildRail(ArrowEntity arrow, double cellW, double cellH) {
    final rail = [
      for (final c in arrow.path) _cellCenter(c, cellW, cellH),
    ];
    // Always extend using tipDirection so exit matches painted head.
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

  /// Rounded corners like Arrow Wave / Arrow GO thin paths.
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
    double cellH,
  ) {
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

    if (isHint && !isExiting) {
      // Heartbeat: scale stroke + glow with pulse (0→1→0 feel via sin).
      final beat = 0.5 + 0.5 * math.sin(hintPulse * math.pi * 2);
      final glowW = stroke * (2.4 + beat * 2.2);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.25 + beat * 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + beat * 10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = glowW
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.55 + beat * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * (1.15 + beat * 0.55)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Soft shadow under thin line (Arrow GO style lift).
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.06 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Arrowhead always matches tip / exit direction (not a mismatched visual).
    final (dr, dc) = tipDir.delta;
    final head = points.last;
    // While exiting through bends mid-path, prefer tipDir once past body,
    // else follow last drawn segment so head stays aligned on the line.
    Offset heading;
    if (isExiting && points.length >= 2) {
      final seg = points.last - points[points.length - 2];
      heading = seg.distance > 0.001
          ? seg
          : Offset(dc * cellW, dr * cellH);
    } else {
      heading = Offset(dc * cellW, dr * cellH);
    }

    final nx = heading.dx / heading.distance;
    final ny = heading.dy / heading.distance;
    // Compact heads — less overlap when paths run close.
    final headLen = stroke * 3.2;
    final headWidth = stroke * 2.4;
    final tip = Offset(head.dx + nx * headLen, head.dy + ny * headLen);
    final base = Offset(head.dx - nx * stroke * 0.2, head.dy - ny * stroke * 0.2);
    final left = Offset(
      base.dx - ny * headWidth,
      base.dy + nx * headWidth,
    );
    final right = Offset(
      base.dx + ny * headWidth,
      base.dy - nx * headWidth,
    );

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(headPath, Paint()..color = strokeColor);
    if (isHint && !isExiting) {
      final beat = 0.5 + 0.5 * math.sin(hintPulse * math.pi * 2);
      canvas.drawPath(
        headPath,
        Paint()
          ..color = color.withValues(alpha: 0.35 + beat * 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + beat * 6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + beat * 2,
      );
    }

    // Tiny tail dot like reference apps (subtle, not chunky).
    if (!isExiting || exitProgress < 0.7) {
      canvas.drawCircle(
        points.first,
        stroke * 0.65,
        Paint()..color = strokeColor,
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
        old.hintPulse != hintPulse ||
        old.arrowColors != arrowColors;
  }
}
