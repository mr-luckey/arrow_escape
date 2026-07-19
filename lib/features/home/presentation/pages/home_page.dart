import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../levels/presentation/bloc/progress_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = Breakpoints.pagePadding(context);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: padding,
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  'ARROW ESCAPE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: colors.onSurface,
                        height: 1.05,
                      ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.15),
                const SizedBox(height: 12),
                Text(
                  'Pull every arrow free — without a clash.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.muted,
                      ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 28),
                _HeroArrows(colors: colors.arrowPalette)
                    .animate()
                    .scale(delay: 100.ms, duration: 600.ms, curve: Curves.easeOutBack),
                const Spacer(flex: 2),
                BlocBuilder<ProgressCubit, ProgressState>(
                  builder: (context, progress) {
                    final continueId = progress.highestUnlocked.clamp(1, 30);
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Settings'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => context.go('/howto'),
                      icon: const Icon(Icons.help_outline_rounded),
                      label: const Text('How to Play'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroArrows extends StatelessWidget {
  const _HeroArrows({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Transform.rotate(
              angle: i * 0.9,
              child: Icon(
                Icons.subdirectory_arrow_right_rounded,
                size: 64 + i * 8.0,
                color: colors[i % colors.length].withValues(alpha: 0.85),
              )
                  .animate(delay: (i * 80).ms)
                  .fadeIn()
                  .slideY(begin: 0.2, curve: Curves.easeOutBack),
            ),
        ],
      ),
    );
  }
}
