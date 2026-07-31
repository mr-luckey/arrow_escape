import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/game_entities.dart';

/// Board-space overlay for the auto-playing marketing demo: a cartoon hand that
/// travels to the arrow about to be tapped, plus a ripple + spark burst on each
/// tap. Lives inside the board's `SizedBox` so it shares its coordinate space.
class DemoBoardOverlay extends StatefulWidget {
  const DemoBoardOverlay({
    super.key,
    required this.boardSize,
    required this.rows,
    required this.cols,
    required this.target,
    required this.tapSeq,
    required this.pressed,
    required this.palette,
    required this.accent,
    required this.travel,
  });

  final Size boardSize;
  final int rows;
  final int cols;

  /// Cell the hand points at. Null hides the hand.
  final Cell? target;

  /// Increments once per tap; each change spawns a burst at [target].
  final int tapSeq;
  final bool pressed;
  final List<Color> palette;
  final Color accent;
  final Duration travel;

  @override
  State<DemoBoardOverlay> createState() => _DemoBoardOverlayState();
}

class _DemoBoardOverlayState extends State<DemoBoardOverlay> {
  final _bursts = <_Burst>[];

  @override
  void didUpdateWidget(covariant DemoBoardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.target;
    if (widget.tapSeq != oldWidget.tapSeq && target != null) {
      setState(() {
        _bursts.add(_Burst(id: widget.tapSeq, cell: target));
      });
    }
  }

  Offset _center(Cell cell) {
    final cellW = widget.boardSize.width / widget.cols;
    final cellH = widget.boardSize.height / widget.rows;
    return Offset((cell.col + 0.5) * cellW, (cell.row + 0.5) * cellH);
  }

  @override
  Widget build(BuildContext context) {
    final short = widget.boardSize.shortestSide;
    final burstRadius = (short * 0.17).clamp(38.0, 88.0);
    final handWidth = (short * 0.27).clamp(70.0, 132.0);
    final target = widget.target;

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final burst in _bursts)
            Positioned(
              left: _center(burst.cell).dx - burstRadius,
              top: _center(burst.cell).dy - burstRadius,
              width: burstRadius * 2,
              height: burstRadius * 2,
              child: _TapBurst(
                key: ValueKey(burst.id),
                seed: burst.id,
                palette: widget.palette,
                accent: widget.accent,
                onDone: () {
                  if (!mounted) return;
                  setState(() => _bursts.remove(burst));
                },
              ),
            ),
          if (target != null)
            AnimatedPositioned(
              duration: widget.travel,
              curve: Curves.easeInOutCubic,
              left: _center(target).dx - handWidth * _handTipX,
              top: _center(target).dy - handWidth * _handAspect * _handTipY,
              width: handWidth,
              height: handWidth * _handAspect,
              child: _CartoonHand(
                width: handWidth,
                pressed: widget.pressed,
              ),
            ),
        ],
      ),
    );
  }
}

class _Burst {
  const _Burst({required this.id, required this.cell});

  final int id;
  final Cell cell;
}

// --- Cartoon hand ---

const _handAsset = 'assets/images/demo_hand.png';

/// Height / width of [_handAsset] (382x715), and the index fingertip position
/// inside it as a fraction of its width and height.
const _handAspect = 715 / 382;
const _handTipX = 0.516;
const _handTipY = 0.03;

class _CartoonHand extends StatefulWidget {
  const _CartoonHand({required this.width, required this.pressed});

  final double width;
  final bool pressed;

  @override
  State<_CartoonHand> createState() => _CartoonHandState();
}

class _CartoonHandState extends State<_CartoonHand>
    with SingleTickerProviderStateMixin {
  /// Resting tilt so the hand reads as reaching in from the lower right instead
  /// of standing bolt upright.
  static const _tilt = -0.15;

  /// Transform origin at the fingertip, so tilting/scaling keeps the contact
  /// point glued to the arrow.
  static const _tipAlignment = Alignment(
    _handTipX * 2 - 1,
    _handTipY * 2 - 1,
  );

  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.pressed ? 1 : 0),
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      builder: (context, press, child) {
        return AnimatedBuilder(
          animation: _idle,
          builder: (context, _) {
            final bob = math.sin(_idle.value * math.pi * 2);
            return Transform.translate(
              offset: Offset(
                press * widget.width * 0.04,
                bob * widget.width * 0.03 + press * widget.width * 0.07,
              ),
              child: Transform.rotate(
                angle: _tilt + bob * 0.03 - press * 0.05,
                alignment: _tipAlignment,
                child: Transform.scale(
                  scale: 1 - press * 0.1,
                  alignment: _tipAlignment,
                  child: child,
                ),
              ),
            );
          },
        );
      },
      child: Stack(
        children: [
          // Blurred, darkened copy of the sticker so it lifts off the board.
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(widget.width * 0.04, widget.width * 0.06),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: widget.width * 0.035,
                  sigmaY: widget.width * 0.035,
                ),
                child: Image.asset(
                  _handAsset,
                  color: Colors.black.withValues(alpha: 0.3),
                  colorBlendMode: BlendMode.srcIn,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              _handAsset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Tap burst ---

class _TapBurst extends StatefulWidget {
  const _TapBurst({
    super.key,
    required this.seed,
    required this.palette,
    required this.accent,
    required this.onDone,
  });

  final int seed;
  final List<Color> palette;
  final Color accent;
  final VoidCallback onDone;

  @override
  State<_TapBurst> createState() => _TapBurstState();
}

class _TapBurstState extends State<_TapBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _TapBurstPainter(
            t: _c.value,
            seed: widget.seed,
            palette: widget.palette,
            accent: widget.accent,
          ),
        ),
      ),
    );
  }
}

class _TapBurstPainter extends CustomPainter {
  _TapBurstPainter({
    required this.t,
    required this.seed,
    required this.palette,
    required this.accent,
  });

  final double t;
  final int seed;
  final List<Color> palette;
  final Color accent;

  static const _sparkCount = 11;

  double _easeOut(double v) => 1 - math.pow(1 - v, 3).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    // Bright flash right at the contact point.
    final flash = (1 - t / 0.22).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawCircle(
        center,
        maxR * 0.34 * (0.5 + 0.5 * flash),
        Paint()..color = Colors.white.withValues(alpha: 0.55 * flash),
      );
    }

    // Two expanding rings, the second slightly delayed.
    for (var i = 0; i < 2; i++) {
      final rt = ((t - i * 0.16) / (1 - i * 0.16)).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final e = _easeOut(rt);
      canvas.drawCircle(
        center,
        maxR * (0.14 + 0.86 * e),
        Paint()
          ..color = accent.withValues(alpha: (1 - rt) * (i == 0 ? 0.85 : 0.45))
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1 - rt) * (i == 0 ? 5.5 : 3.5),
      );
    }

    // Sparks flying outward with a little gravity.
    final e = _easeOut(t);
    for (var i = 0; i < _sparkCount; i++) {
      final angle = (i / _sparkCount) * math.pi * 2 + seed * 0.37;
      final reach = maxR * (0.62 + ((i * 7 + seed) % 5) * 0.09);
      final dx = math.cos(angle) * reach * e;
      final dy = math.sin(angle) * reach * e + maxR * 0.5 * t * t;
      final color = i.isEven
          ? palette[(i + seed) % palette.length]
          : (i % 3 == 0 ? Colors.white : accent);
      canvas.drawCircle(
        center + Offset(dx, dy),
        maxR * 0.09 * (1 - t),
        Paint()..color = color.withValues(alpha: (1 - t).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TapBurstPainter old) => old.t != t;
}

// --- Win confetti ---

/// Full-screen confetti rain used when the demo clears a level.
class DemoConfetti extends StatefulWidget {
  const DemoConfetti({super.key, required this.palette});

  final List<Color> palette;

  @override
  State<DemoConfetti> createState() => _DemoConfettiState();
}

class _DemoConfettiState extends State<DemoConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(t: _c.value, palette: widget.palette),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.palette})
      : _random = math.Random(7);

  final double t;
  final List<Color> palette;
  final math.Random _random;

  static const _count = 90;

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic per-piece params so pieces don't jitter between frames.
    for (var i = 0; i < _count; i++) {
      final x0 = _random.nextDouble();
      final delay = _random.nextDouble() * 0.5;
      final speed = 0.75 + _random.nextDouble() * 0.55;
      final swayPhase = _random.nextDouble() * math.pi * 2;
      final spin = (_random.nextDouble() - 0.5) * 10;
      final w = 6.0 + _random.nextDouble() * 7;
      final h = 9.0 + _random.nextDouble() * 9;
      final color = palette[i % palette.length];

      final local = ((t - delay) * speed) % 1.0;
      if (t < delay) continue;

      final y = -0.08 * size.height + local * size.height * 1.2;
      final x = x0 * size.width +
          math.sin(local * math.pi * 4 + swayPhase) * size.width * 0.05;
      final fade = local > 0.82 ? (1 - (local - 0.82) / 0.18) : 1.0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * spin + swayPhase);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(2.5),
        ),
        Paint()..color = color.withValues(alpha: fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
