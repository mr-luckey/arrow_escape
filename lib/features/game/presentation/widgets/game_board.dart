import 'dart:math' as math;
import 'dart:ui' as ui;

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
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final aspect = cols / rows;
        double width = maxW;
        double height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
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
                  ),
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
    final row = (pos.dy / cellH).floor();
    final col = (pos.dx / cellW).floor();
    if (row < 0 || col < 0 || row >= rows || col >= cols) return null;
    for (final arrow in arrows) {
      if (arrow.path.any((c) => c.row == row && c.col == col)) {
        return arrow.id;
      }
    }
    return null;
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
  });

  final int rows;
  final int cols;
  final List<ArrowEntity> arrows;
  final List<Color> arrowColors;
  final String? hintArrowId;
  final String? failedArrowId;
  final String? removedArrowId;
  final double exitProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final bg = Paint()..color = const Color(0xFFFFFFF8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(24),
      ),
      bg,
    );

    final border = Paint()
      ..color = const Color(0xFFE2EEF5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3),
        const Radius.circular(24),
      ),
      border,
    );

    final grid = Paint()
      ..color = const Color(0x10000000)
      ..strokeWidth = 1;
    for (var r = 1; r < rows; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), grid);
    }
    for (var c = 1; c < cols; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 12), Offset(x, size.height - 12), grid);
    }

    for (final arrow in arrows) {
      _paintArrow(canvas, arrow, cellW, cellH);
    }
  }

  Offset _cellCenter(Cell c, double cellW, double cellH) =>
      Offset((c.col + 0.5) * cellW, (c.row + 0.5) * cellH);

  /// Continuous rail: body cells (tail → head) then exit lane off the board.
  List<Offset> _buildRail(ArrowEntity arrow, double cellW, double cellH) {
    final rail = [
      for (final c in arrow.path) _cellCenter(c, cellW, cellH),
    ];
    final (dr, dc) = arrow.direction.delta;
    final extend = arrow.path.length + math.max(rows, cols) + 3;
    var tip = rail.last;
    for (var i = 0; i < extend; i++) {
      tip = Offset(tip.dx + dc * cellW, tip.dy + dr * cellH);
      rail.add(tip);
    }
    return rail;
  }

  /// Sample a point along rail where [index] is in cell units (can be fractional).
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

  /// Vertices of the arrow after sliding [travel] cell-units along its rail.
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

    // Pull-out: every vertex advances along the polyline rail (snakes through bends).
    final travel = isExiting
        ? exitProgress * (arrow.path.length + math.max(rows, cols) + 2)
        : 0.0;
    final points = isExiting
        ? _slidingPoints(arrow, cellW, cellH, travel)
        : [for (final c in arrow.path) _cellCenter(c, cellW, cellH)];

    if (points.length < 2 && points.isEmpty) return;

    // Fade as it clears the board.
    final opacity = isExiting ? (1.0 - exitProgress * 0.35).clamp(0.35, 1.0) : 1.0;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    if (isHint && !isExiting) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellW * 0.55
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.28 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellW * 0.48
        ..strokeCap = StrokeCap.round,
    );

    final strokeColor = (isFailed ? const Color(0xFFFF3B3B) : color)
        .withValues(alpha: opacity);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellW * 0.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Arrowhead oriented along current travel direction (last segment).
    final head = points.last;
    Offset heading;
    if (points.length >= 2) {
      heading = points.last - points[points.length - 2];
    } else {
      final (dr, dc) = arrow.direction.delta;
      heading = Offset(dc.toDouble(), dr.toDouble());
    }
    final len = heading.distance;
    if (len < 0.001) {
      final (dr, dc) = arrow.direction.delta;
      heading = Offset(dc * cellW, dr * cellH);
    }
    final nx = heading.dx / heading.distance;
    final ny = heading.dy / heading.distance;
    final tip = Offset(head.dx + nx * cellW * 0.4, head.dy + ny * cellH * 0.4);
    final px = -ny;
    final py = nx;
    final left = Offset(
      head.dx + px * cellW * 0.3 - nx * cellW * 0.02,
      head.dy + py * cellH * 0.3 - ny * cellH * 0.02,
    );
    final right = Offset(
      head.dx - px * cellW * 0.3 - nx * cellW * 0.02,
      head.dy - py * cellH * 0.3 - ny * cellH * 0.02,
    );

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(headPath, Paint()..color = strokeColor);

    // Tail nub only while mostly still on the board.
    if (!isExiting || exitProgress < 0.85) {
      canvas.drawCircle(
        points.first,
        cellW * 0.15,
        Paint()..color = Colors.white.withValues(alpha: 0.9 * opacity),
      );
      canvas.drawCircle(
        points.first,
        cellW * 0.1,
        Paint()..color = strokeColor,
      );
    }

    // Soft motion streak while exiting.
    if (isExiting && exitProgress > 0.05 && points.length >= 2) {
      final streak = Paint()
        ..shader = ui.Gradient.linear(
          points.first,
          points.last,
          [
            strokeColor.withValues(alpha: 0),
            strokeColor.withValues(alpha: 0.2),
          ],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellW * 0.22
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, streak);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) {
    return old.arrows != arrows ||
        old.hintArrowId != hintArrowId ||
        old.failedArrowId != failedArrowId ||
        old.removedArrowId != removedArrowId ||
        old.exitProgress != exitProgress ||
        old.arrowColors != arrowColors;
  }
}
