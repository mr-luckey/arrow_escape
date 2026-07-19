import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/store/app_store_service.dart';
import '../../../../core/store/rate_app_dialog.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../levels/presentation/bloc/progress_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_onHomeReady());
    });
  }

  Future<void> _onHomeReady() async {
    final store = sl<AppStoreService>();
    await store.prepareSession();
    await store.checkForUpdate();

    if (!mounted) return;

    // Let the home UI settle, then maybe soft-ask for a rating.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (store.shouldShowRatePrompt()) {
      await showRateAppDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = Breakpoints.pagePadding(context);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: padding,
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      Text(
                        'ARROW ESCAPE',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: colors.primary,
                                  height: 1.05,
                                ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: -0.12),
                      const SizedBox(height: 12),
                      Text(
                        'Pull every arrow free — without a clash.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colors.muted,
                            ),
                      ).animate().fadeIn(delay: 120.ms),
                      const Spacer(flex: 3),
                      BlocBuilder<ProgressCubit, ProgressState>(
                        builder: (context, progress) {
                          final maxId = progress.levels.isEmpty
                              ? 1000
                              : progress.levels.length;
                          final continueId =
                              progress.highestUnlocked.clamp(1, maxId);
                          return AppPrimaryButton(
                            label: progress.highestUnlocked > 1
                                ? 'Continue Level $continueId'
                                : 'Play',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () => context.go('/game/$continueId'),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      AppSecondaryButton(
                        label: 'Level Select',
                        onPressed: () => context.go('/levels'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => context.go('/settings'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.settings_rounded,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Settings',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => context.go('/howto'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.help_outline_rounded,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'How to Play',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const BannerAdWidget(height: 50),
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }
}
