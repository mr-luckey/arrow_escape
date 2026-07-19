import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/domain/entities/game_entities.dart';
import '../bloc/progress_cubit.dart';

class LevelSelectPage extends StatelessWidget {
  const LevelSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = Breakpoints.pagePadding(context);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: padding.copyWith(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SoftIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => context.go('/'),
                    ),
                    const SizedBox(width: 12),
                    Text('Levels', style: Theme.of(context).textTheme.displayMedium),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: BlocBuilder<ProgressCubit, ProgressState>(
                    builder: (context, state) {
                      if (state.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return DefaultTabController(
                        length: 3,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: colors.surface.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TabBar(
                                labelColor: colors.onSurface,
                                indicator: BoxDecoration(
                                  color: colors.secondary.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                tabs: const [
                                  Tab(text: 'Easy'),
                                  Tab(text: 'Medium'),
                                  Tab(text: 'Hard'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _LevelGrid(
                                    levels: state.levels
                                        .where((l) =>
                                            l.difficulty == LevelDifficulty.easy)
                                        .toList(),
                                    progress: state,
                                  ),
                                  _LevelGrid(
                                    levels: state.levels
                                        .where((l) =>
                                            l.difficulty ==
                                            LevelDifficulty.medium)
                                        .toList(),
                                    progress: state,
                                  ),
                                  _LevelGrid(
                                    levels: state.levels
                                        .where((l) =>
                                            l.difficulty == LevelDifficulty.hard)
                                        .toList(),
                                    progress: state,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelGrid extends StatelessWidget {
  const _LevelGrid({required this.levels, required this.progress});

  final List<LevelEntity> levels;
  final ProgressState progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cross = Breakpoints.isTablet(context) ? 5 : 4;

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: levels.length,
      itemBuilder: (context, index) {
        final level = levels[index];
        final unlocked = progress.isUnlocked(level.id);
        final stars = progress.starsFor(level.id);

        return Material(
          color: unlocked
              ? colors.surface
              : colors.muted.withValues(alpha: 0.15),
          elevation: unlocked ? 2 : 0,
          shadowColor: colors.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: unlocked ? () => context.go('/game/${level.id}') : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!unlocked)
                  Icon(Icons.lock_rounded, color: colors.muted, size: 26)
                else ...[
                  Text(
                    '${level.id}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: colors.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: i < stars
                            ? colors.accent
                            : colors.muted.withValues(alpha: 0.3),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        )
            .animate(delay: ((index > 24 ? 24 : index) * 20).ms)
            .fadeIn()
            .scale(begin: const Offset(0.9, 0.9));
      },
    );
  }
}
