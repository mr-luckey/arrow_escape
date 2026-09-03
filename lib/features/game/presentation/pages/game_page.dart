import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ads_service.dart';
import '../../../../core/ads/banner_ad_slot.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/audio/audio_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/haptics/haptics_service.dart';
import '../../../../core/theme/app_theme_extension.dart';
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
      create: (_) {
        sl<AudioService>().prepareLevelTune(levelId);
        unawaited(
          sl<AnalyticsService>().logLevelStarted(
            levelNumber: levelId,
            source: 'game',
          ),
        );
        return GameBloc(
          levelRepository: sl(),
          progressRepository: sl(),
          applyMove: sl<ApplyMoveUseCase>(),
          getHint: sl(),
        )..add(GameStarted(levelId));
      },
      child: const _GameView(),
    );
  }
}

class _GameView extends StatefulWidget {
  const _GameView();

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> {
  bool _hintBusy = false;

  Future<void> _onHint() async {
    // Hard UI + service lock — spam taps never queue a second rewarded ad.
    if (_hintBusy || !mounted) return;
    final ads = sl<AdsService>();
    if (ads.isFullScreenBusy) return;

    setState(() => _hintBusy = true);
    try {
      // Fully offline: skip AdMob and grant the hint so gameplay continues.
      if (!ads.isOnline) {
        _grantHint(source: 'offline');
        return;
      }

      final earned = await ads.showRewardedForHint();
      if (!mounted) return;
      if (earned) {
        _grantHint(source: 'rewarded');
        return;
      }

      // Online but no fill / skipped — do not grant; keep play flowing.
      if (!ads.isOnline) {
        _grantHint(source: 'offline');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hint ad unavailable. Try again in a moment.'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _hintBusy = false);
    }
  }

  void _grantHint({required String source}) {
    if (!mounted) return;
    final level = context.read<GameBloc>().state.level;
    if (source == 'rewarded') {
      unawaited(
        sl<AnalyticsService>().logRewardedAdCompleted(
          placement: 'hint',
          source: 'game',
        ),
      );
    }
    unawaited(
      sl<AnalyticsService>().logHintUsed(
        levelNumber: level?.id,
        source: source,
      ),
    );
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
                p.moveCount != c.moveCount ||
                p.status != c.status ||
                p.lastFailedArrowId != c.lastFailedArrowId ||
                p.lastRemovedArrowId != c.lastRemovedArrowId,
            buildWhen: (p, c) =>
                p.status != c.status ||
                p.arrows != c.arrows ||
                p.hearts != c.hearts ||
                p.hintArrowId != c.hintArrowId ||
                p.lastFailedArrowId != c.lastFailedArrowId ||
                p.lastRemovedArrowId != c.lastRemovedArrowId ||
                p.level?.id != c.level?.id ||
                p.moveCount != c.moveCount,
            listener: (context, state) {
              final audio = sl<AudioService>();
              final haptics = sl<HapticsService>();
              // Keep in sync with settings (factory cubit can be recreated).
              haptics.setEnabled(
                context.read<SettingsCubit>().state.hapticsEnabled,
              );

              final level = state.level;
              if (state.status == GameStatus.animating &&
                  state.lastRemovedArrowId != null &&
                  level != null) {
                // The escaping arrow is still on the board at this point, so
                // the count of already-cleared arrows is the note to strike.
                audio.playArrowNote(
                  levelId: level.id,
                  index: level.arrows.length - state.arrows.length,
                );
                haptics.light();
              }

              if (state.lastFailedArrowId != null &&
                  state.status == GameStatus.playing) {
                audio.playWrong();
                haptics.medium();
              }

              if (state.status == GameStatus.won) {
                audio.playWin();
                haptics.heavy();
                context.read<ProgressCubit>().refresh();
                unawaited(
                  sl<AnalyticsService>().logLevelCompleted(
                    levelNumber: state.level?.id,
                    moves: state.moveCount,
                    source: 'game',
                  ),
                );
                unawaited(sl<AdsService>().maybeShowInterstitialOnLevelEnd());
              } else if (state.status == GameStatus.lost) {
                audio.playLose();
                haptics.heavy();
                context.read<ProgressCubit>().refresh();
                unawaited(
                  sl<AnalyticsService>().logLevelFailed(
                    levelNumber: state.level?.id,
                    moves: state.moveCount,
                    source: 'game',
                  ),
                );
                unawaited(sl<AdsService>().maybeShowInterstitialOnLevelEnd());
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

              return Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        child: GameHud(
                          levelLabel: 'LEVEL ${level.id}',
                          hearts: state.hearts,
                          maxHearts: state.maxHearts,
                          hintBusy: _hintBusy,
                          onBack: () {
                            unawaited(
                              sl<AdsService>().runAfterInterstitialBreak(
                                placement: 'leave_game',
                                onContinue: () {
                                  if (context.mounted) {
                                    context.go('/levels');
                                  }
                                },
                              ),
                            );
                          },
                          onReset: () => context
                              .read<GameBloc>()
                              .add(const ResetRequested()),
                          onHint: _onHint,
                          onSettings: () {
                            unawaited(
                              sl<AdsService>().runAfterInterstitialBreak(
                                placement: 'open_settings',
                                onContinue: () {
                                  if (context.mounted) {
                                    context.go('/settings');
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      // Space after hearts before playfield.
                      const SizedBox(height: 20),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: AppCard(
                            elevation: 10,
                            borderRadius: 22,
                            padding: const EdgeInsets.all(12),
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
                                      failedArrowId: state.lastFailedArrowId,
                                      removedArrowId: state.lastRemovedArrowId,
                                      exitProgress: progress,
                                      hintPulse: pulse,
                                      enabled:
                                          state.status == GameStatus.playing,
                                      onArrowTapped: (id) {
                                        sl<HapticsService>().setEnabled(
                                          context
                                              .read<SettingsCubit>()
                                              .state
                                              .hapticsEnabled,
                                        );
                                        sl<HapticsService>().selection();
                                        context
                                            .read<GameBloc>()
                                            .add(ArrowTapped(id));
                                      },
                                    );

                                    return board;
                                  },
                                );
                              },
                            ),
                          ),
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
                        // Level-end interstitial already handled in listener.
                        context.go('/game/${level.id + 1}');
                      },
                      onReplay: () {
                        context.read<GameBloc>().add(GameStarted(level.id));
                      },
                      onHome: () {
                        unawaited(
                          sl<AdsService>().runAfterInterstitialBreak(
                            placement: 'leave_game',
                            onContinue: () {
                              if (context.mounted) context.go('/');
                            },
                          ),
                        );
                      },
                    ),
                  if (state.status == GameStatus.lost)
                    LoseOverlay(
                      onRetry: () {
                        context.read<GameBloc>().add(GameStarted(level.id));
                      },
                      onHome: () {
                        unawaited(
                          sl<AdsService>().runAfterInterstitialBreak(
                            placement: 'leave_game',
                            onContinue: () {
                              if (context.mounted) context.go('/');
                            },
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: const BannerAdSlot(placement: 'game'),
      ),
    );
  }
}
