import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ads_service.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../levels/presentation/bloc/progress_cubit.dart';
import '../../../settings/presentation/bloc/settings_cubit.dart';
import '../../domain/usecases/game_usecases.dart';
import '../bloc/game_bloc.dart';
import '../widgets/game_board.dart';
import '../widgets/game_hud.dart';
import '../widgets/hint_pulse.dart';

class GamePage extends StatelessWidget {
  const GamePage({super.key, required this.levelId});

  final int levelId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameBloc(
        levelRepository: sl(),
        progressRepository: sl(),
        applyMove: sl<ApplyMoveUseCase>(),
        getHint: sl(),
      )..add(GameStarted(levelId)),
      child: const _GameView(),
    );
  }
}

class _GameView extends StatelessWidget {
  const _GameView();

  Future<void> _onHint(BuildContext context) async {
    final ads = sl<AdsService>();
    final earned = await ads.showRewardedForHint();
    if (!context.mounted || !earned) return;
    context.read<GameBloc>().add(const HintRequested());
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: BlocConsumer<GameBloc, GameState>(
            listenWhen: (p, c) =>
                p.lastFailedArrowId != c.lastFailedArrowId ||
                p.status != c.status,
            listener: (context, state) {
              final settings = context.read<SettingsCubit>().state;
              if (state.lastFailedArrowId != null &&
                  state.status == GameStatus.playing) {
                if (settings.hapticsEnabled) {
                  HapticFeedback.mediumImpact();
                }
              }
              if (state.status == GameStatus.won ||
                  state.status == GameStatus.lost) {
                context.read<ProgressCubit>().refresh();
                sl<AdsService>().maybeShowInterstitialOnLevelEnd();
              }
            },
            builder: (context, state) {
              if (state.status == GameStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == GameStatus.error || state.level == null) {
                return Center(
                  child: Text(state.errorMessage ?? 'Failed to load level'),
                );
              }

              final level = state.level!;
              final colors = context.colors;
              final totalLevels =
                  context.read<ProgressCubit>().state.levels.length;
              final hasNext =
                  totalLevels == 0 ? level.id < 1000 : level.id < totalLevels;

              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                              child: GameHud(
                                levelLabel: 'LEVEL ${level.id}',
                                hearts: state.hearts,
                                maxHearts: state.maxHearts,
                                onBack: () => context.go('/levels'),
                                onReset: () => context
                                    .read<GameBloc>()
                                    .add(const ResetRequested()),
                                onHint: () => _onHint(context),
                                onTheme: () =>
                                    context.read<ThemeCubit>().cycle(),
                              ),
                            ),
                            // Space after hearts before playfield.
                            const SizedBox(height: 20),
                            Expanded(
                              child: ExitAnimationGate(
                                status: state.status,
                                animationKey: state.lastRemovedArrowId == null
                                    ? null
                                    : '${state.lastRemovedArrowId}-${state.moveCount}',
                                onCompleted: () => context
                                    .read<GameBloc>()
                                    .add(const AnimationCompleted()),
                                child: (progress) {
                                  return HintPulse(
                                    active: state.hintArrowId != null &&
                                        state.status == GameStatus.playing,
                                    builder: (context, pulse) {
                                      final board = GameBoard(
                                        rows: level.rows,
                                        cols: level.cols,
                                        arrows: state.arrows,
                                        arrowColors: colors.arrowPalette,
                                        hintArrowId: state.hintArrowId,
                                        failedArrowId:
                                            state.lastFailedArrowId,
                                        removedArrowId:
                                            state.lastRemovedArrowId,
                                        exitProgress: progress,
                                        hintPulse: pulse,
                                        enabled: state.status ==
                                            GameStatus.playing,
                                        onArrowTapped: (id) {
                                          final settings = context
                                              .read<SettingsCubit>()
                                              .state;
                                          if (settings.hapticsEnabled) {
                                            HapticFeedback.selectionClick();
                                          }
                                          context
                                              .read<GameBloc>()
                                              .add(ArrowTapped(id));
                                        },
                                      );

                                      if (state.lastFailedArrowId != null &&
                                          state.status ==
                                              GameStatus.playing) {
                                        return TweenAnimationBuilder<double>(
                                          key: ValueKey(
                                            '${state.lastFailedArrowId}-${state.moveCount}',
                                          ),
                                          tween: Tween(begin: -8, end: 8),
                                          duration: const Duration(
                                            milliseconds: 80,
                                          ),
                                          curve: Curves.easeInOut,
                                          builder: (context, value, child) {
                                            return Transform.translate(
                                              offset: Offset(value, 0),
                                              child: child,
                                            );
                                          },
                                          child: board,
                                        );
                                      }
                                      return board;
                                    },
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Text(
                                level.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ),
                        if (state.status == GameStatus.won)
                          WinOverlay(
                            stars: state.earnedStars,
                            hasNext: hasNext,
                            onNext: () {
                              context.go('/game/${level.id + 1}');
                            },
                            onReplay: () {
                              context
                                  .read<GameBloc>()
                                  .add(GameStarted(level.id));
                            },
                            onHome: () => context.go('/'),
                          ),
                        if (state.status == GameStatus.lost)
                          LoseOverlay(
                            onRetry: () {
                              context
                                  .read<GameBloc>()
                                  .add(GameStarted(level.id));
                            },
                            onHome: () => context.go('/'),
                          ),
                      ],
                    ),
                  ),
                  // Reserved banner slot — only free space left for ads.
                  const BannerAdWidget(height: 50),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
