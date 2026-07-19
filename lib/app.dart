import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/levels/presentation/bloc/progress_cubit.dart';
import 'features/settings/presentation/bloc/settings_cubit.dart';

class ArrowEscapeApp extends StatelessWidget {
  ArrowEscapeApp({super.key}) : _router = createRouter();

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
            title: 'Arrow Escape',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(scheme),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
