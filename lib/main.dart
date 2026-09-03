import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/ads/ads_service.dart';
import 'core/analytics/analytics_service.dart';
import 'core/audio/audio_service.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await configureDependencies();

  // Never block first frame on audio / ads / analytics.
  unawaited(_initAudioSafe());
  unawaited(_initBackgroundServices());

  runApp(ColorPathOutApp());
}

Future<void> _initAudioSafe() async {
  try {
    await sl<AudioService>().init().timeout(const Duration(seconds: 4));
  } catch (error) {
    debugPrint('Audio init skipped/timeout: $error');
  }
}

Future<void> _initBackgroundServices() async {
  try {
    await sl<AnalyticsService>().init().timeout(const Duration(seconds: 3));
  } catch (_) {}

  try {
    // Ads SDK can be slow on first cold start with a new production App ID.
    // Do not treat a soft timeout as fatal — AdsService keeps init in flight.
    await sl<AdsService>().init().timeout(const Duration(seconds: 20));
  } catch (error) {
    debugPrint('Ads init skipped/timeout: $error');
  }
}
