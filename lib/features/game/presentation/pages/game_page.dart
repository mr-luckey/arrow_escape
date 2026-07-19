import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../levels/presentation/bloc/progress_cubit.dart';
import '../../../settings/presentation/bloc/settings_cubit.dart';
import '../../domain/usecases/game_usecases.dart';
import '../bloc/game_bloc.dart';
import '../widgets/game_board.dart';
import '../widgets/game_hud.dart';

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

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
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
              final padding = Breakpoints.pagePadding(context);

              return Stack(
                children: [
                  Padding(
                    padding: padding.copyWith(top: 8, bottom: 16),
                    child: Column(
                      children: [
                        GameHud(
                          levelLabel: 'LEVEL ${level.id}',
                          hearts: state.hearts,
                          maxHearts: state.maxHearts,
                          canUndo: state.undoStack.isNotEmpty,
                          onBack: () => context.go('/levels'),
                          onUndo: () =>
                              context.read<GameBloc>().add(const UndoRequested()),
                          onReset: () =>
                              context.read<GameBloc>().add(const ResetRequested()),
                          onHint: () =>
                              context.read<GameBloc>().add(const HintRequested()),
                          onTheme: () => context.read<ThemeCubit>().cycle(),
                        ),
                        const SizedBox(height: 12),
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
                              final board = GameBoard(
                                rows: level.rows,
                                cols: level.cols,
                                arrows: state.arrows,
                                arrowColors: colors.arrowPalette,
                                hintArrowId: state.hintArrowId,
                                failedArrowId: state.lastFailedArrowId,
                                removedArrowId: state.lastRemovedArrowId,
                                exitProgress: progress,
                                enabled: state.status == GameStatus.playing,
                                onArrowTapped: (id) {
                                  final settings =
                                      context.read<SettingsCubit>().state;
                                  if (settings.hapticsEnabled) {
                                    HapticFeedback.selectionClick();
                                  }
                                  context
                                      .read<GameBloc>()
                                      .add(ArrowTapped(id));
                                },
                              );

                              if (state.lastFailedArrowId != null &&
                                  state.status == GameStatus.playing) {
                                return TweenAnimationBuilder<double>(
                                  key: ValueKey(
                                    '${state.lastFailedArrowId}-${state.moveCount}',
                                  ),
                                  tween: Tween(begin: -8, end: 8),
                                  duration: const Duration(milliseconds: 80),
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
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          level.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  if (state.status == GameStatus.won)
                    WinOverlay(
                      stars: state.earnedStars,
                      hasNext: level.id < 30,
                      onNext: () {
                        context.go('/game/${level.id + 1}');
                      },
                      onReplay: () {
                        context.read<GameBloc>().add(GameStarted(level.id));
                      },
                      onHome: () => context.go('/'),
                    ),
                  if (state.status == GameStatus.lost)
                    LoseOverlay(
                      onRetry: () {
                        context.read<GameBloc>().add(GameStarted(level.id));
                      },
                      onHome: () => context.go('/'),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
