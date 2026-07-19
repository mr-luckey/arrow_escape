import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/game/presentation/pages/game_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/howto/presentation/pages/how_to_play_page.dart';
import '../../features/levels/presentation/pages/level_select_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/levels',
        builder: (context, state) => const LevelSelectPage(),
      ),
      GoRoute(
        path: '/game/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '1') ?? 1;
          return GamePage(key: ValueKey(id), levelId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/howto',
        builder: (context, state) => const HowToPlayPage(),
      ),
    ],
  );
}
