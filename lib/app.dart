import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/audio/audio_service.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/levels/presentation/bloc/progress_cubit.dart';
import 'features/settings/presentation/bloc/settings_cubit.dart';

class ColorPathOutApp extends StatelessWidget {
  ColorPathOutApp({super.key}) : _router = createRouter();

  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ThemeCubit>()),
        BlocProvider(create: (_) => sl<SettingsCubit>()),
        BlocProvider(create: (_) => sl<ProgressCubit>()..load()),
      ],
      child: BlocBuilder<ThemeCubit, AppColorSchemeId>(
        builder: (context, scheme) {
          return MaterialApp.router(
            title: 'ColorPath Out',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(scheme),
            routerConfig: _router,
            builder: (context, child) {
              return _AudioLifecycle(
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}

/// Starts chill BGM and pauses/resumes with app lifecycle.
class _AudioLifecycle extends StatefulWidget {
  const _AudioLifecycle({required this.child});

  final Widget child;

  @override
  State<_AudioLifecycle> createState() => _AudioLifecycleState();
}

class _AudioLifecycleState extends State<_AudioLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sl<AudioService>().startBgm();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = sl<AudioService>();
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(audio.ensureBgmPlaying(forceRestart: true));
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(audio.pauseBgm());
      case AppLifecycleState.inactive:
        // Don't pause on inactive — ads/system UI spam this and kill BGM.
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
