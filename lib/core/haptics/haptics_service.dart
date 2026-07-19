import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Reliable cross-platform haptics for real devices.
///
/// On many Android phones [HapticFeedback] alone is too weak / ignored.
/// We use the Vibration API (needs VIBRATE permission) as primary path.
class HapticsService {
  HapticsService();

  bool _enabled = true;
  bool? _hasVibrator;

  void setEnabled(bool enabled) => _enabled = enabled;

  bool get isEnabled => _enabled;

  Future<bool> _canVibrate() async {
    if (kIsWeb) return false;
    if (_hasVibrator != null) return _hasVibrator!;
    try {
      _hasVibrator = await Vibration.hasVibrator();
    } catch (_) {
      _hasVibrator = false;
    }
    return _hasVibrator ?? false;
  }

  Future<void> _buzz({
    required int durationMs,
    required int amplitude,
    required Future<void> Function() flutterFallback,
  }) async {
    if (!_enabled) return;
    try {
      if (!kIsWeb && Platform.isAndroid && await _canVibrate()) {
        if (await Vibration.hasAmplitudeControl()) {
          await Vibration.vibrate(
            duration: durationMs,
            amplitude: amplitude.clamp(1, 255),
          );
        } else {
          await Vibration.vibrate(duration: durationMs);
        }
        return;
      }
    } catch (_) {}

    try {
      await flutterFallback();
      // Extra system vibrate for iOS / edge Android cases.
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  Future<void> selection() => _buzz(
        durationMs: 22,
        amplitude: 110,
        flutterFallback: HapticFeedback.selectionClick,
      );

  Future<void> light() => _buzz(
        durationMs: 32,
        amplitude: 140,
        flutterFallback: HapticFeedback.lightImpact,
      );

  Future<void> medium() => _buzz(
        durationMs: 55,
        amplitude: 200,
        flutterFallback: HapticFeedback.mediumImpact,
      );

  Future<void> heavy() => _buzz(
        durationMs: 80,
        amplitude: 255,
        flutterFallback: HapticFeedback.heavyImpact,
      );

  /// Preview when enabling haptics in Settings.
  Future<void> testPulse() async {
    final was = _enabled;
    _enabled = true;
    await medium();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await light();
    _enabled = was;
  }
}
