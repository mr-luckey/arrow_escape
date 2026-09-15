import 'package:flutter/foundation.dart';

/// Haptics / vibration — permanently disabled for this build.
///
/// Call sites and Settings toggle remain so the API stays stable;
/// nothing vibrates.
class HapticsService {
  HapticsService();

  bool get isEnabled => false;

  void setEnabled(bool enabled) {
    if (kDebugMode && enabled) {
      debugPrint('HapticsService: vibration disabled — ignoring enable');
    }
  }

  Future<void> selection() async {}

  Future<void> light() async {}

  Future<void> medium() async {}

  Future<void> heavy() async {}

  Future<void> testPulse() async {}
}
