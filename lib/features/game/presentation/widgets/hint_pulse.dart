import 'package:flutter/material.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/di/injection.dart';

/// Heartbeat pulse for the hinted arrow — fires a thump each cycle.
/// Uses a single AnimatedBuilder so only the board painter ticks, not the page.
class HintPulse extends StatefulWidget {
  const HintPulse({
    super.key,
    required this.active,
    required this.builder,
  });

  final bool active;
  final Widget Function(BuildContext context, double pulse) builder;

  @override
  State<HintPulse> createState() => _HintPulseState();
}

class _HintPulseState extends State<HintPulse>
    with SingleTickerProviderStateMixin {
  static const _beatMs = 720;

  late final AnimationController _controller;
  bool _beatArmed = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _beatMs),
    )..addListener(_onTick);

    if (widget.active) {
      _startBeat();
    }
  }

  void _onTick() {
    if (!widget.active) return;
    final v = _controller.value;
    if (v < 0.08) {
      if (_beatArmed) {
        _beatArmed = false;
        sl<AudioService>().playHintThump();
      }
    } else if (v > 0.25) {
      _beatArmed = true;
    }
  }

  void _startBeat() {
    sl<AudioService>().armHintBeat();
    _beatArmed = false;
    _controller.repeat();
    sl<AudioService>().playHintThump();
  }

  void _stopBeat() {
    _controller
      ..stop()
      ..value = 0;
    sl<AudioService>().stopHintBeat();
  }

  @override
  void didUpdateWidget(covariant HintPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _startBeat();
    } else if (!widget.active && oldWidget.active) {
      _stopBeat();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    sl<AudioService>().stopHintBeat();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.builder(context, 0);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }
}
