import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/ads/ads_service.dart';
import 'core/audio/audio_service.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await configureDependencies();
  await sl<AudioService>().init();
  // Never block / crash launch if ads SDK fails (Play pre-launch devices).
  try {
    await sl<AdsService>().init();
  } catch (_) {}
  runApp(ColorPathOutApp());
}
