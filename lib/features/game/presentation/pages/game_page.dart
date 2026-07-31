import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ads_service.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/audio/audio_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/haptics/haptics_service.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../levels/presentation/bloc/progress_cubit.dart';
import '../../../settings/presentation/bloc/settings_cubit.dart';
import '../../domain/entities/game_entities.dart';
import '../../domain/usecases/game_usecases.dart';
import '../bloc/game_bloc.dart';
import '../widgets/demo_overlay.dart';
import '../widgets/game_board.dart';
import '../widgets/game_hud.dart';
import '../widgets/hint_pulse.dart';

/// Level opened by the marketing demo from the home screen.
const kDemoLevelId = 999;

class GamePage extends StatelessWidget {
  const GamePage({super.key, required this.levelId, this.demoMode = false});

  final int levelId;

  /// Auto-plays the level with an animated cartoon hand, for recording promo
  /// footage. Saved progress and interstitials are left untouched.
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        sl<AudioService>().prepareLevelTune(levelId);
        return GameBloc(
          levelRepository: sl(),
          progressRepository: sl(),
          applyMove: sl<ApplyMoveUseCase>(),
          getHint: sl(),
          demoMode: demoMode,
        )..add(GameStarted(levelId));
      },
      child: _GameView(demoMode: demoMode),
    );
  }
}

class _GameView extends StatefulWidget {
  const _GameView({required this.demoMode});

  final bool demoMode;

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> {
  // Demo pacing. A move is: travel → press → tap → short gap, and the board's
  // own exit animation (420ms) overlaps the travel to the next arrow.
  static const _handTravel = Duration(milliseconds: 340);
  static const _handPress = Duration(milliseconds: 120);
  static const _afterTap = Duration(milliseconds: 80);
  static const _demoIntro = Duration(milliseconds: 900);
  static const _demoRestart = Duration(milliseconds: 5200);

  Cell? _handCell;
  int _tapSeq = 0;
  bool _handPressed = false;
  bool _demoRunning = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runDemo());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<bool> _wait(Duration duration) async {
    await Future<void>.delayed(duration);
    return mounted && !_disposed;
  }

  /// Blocks until the bloc can accept another tap (the previous arrow has
  /// finished sliding off the board).
  Future<bool> _waitForPlaying(
    GameBloc bloc, {
    bool abortWhenFinished = true,
    int maxTicks = 200,
  }) async {
    for (var i = 0; i < maxTicks; i++) {
      if (!mounted || _disposed) return false;
      final status = bloc.state.status;
      if (status == GameStatus.playing) return true;
      if (status == GameStatus.error) return false;
      if (abortWhenFinished &&
          (status == GameStatus.won || status == GameStatus.lost)) {
        return false;
      }
      if (!await _wait(const Duration(milliseconds: 16))) return false;
    }
    return false;
  }

  Future<void> _runDemo() async {
    if (_demoRunning) return;
    _demoRunning = true;
    final bloc = context.read<GameBloc>();
    final getHint = sl<GetHintUseCase>();

    while (!_disposed) {
      // Level load (and the pause after a restart) can outlast a normal move.
      final ready = await _waitForPlaying(
        bloc,
        abortWhenFinished: false,
        maxTicks: 900,
      );
      if (!ready) return;
      final level = bloc.state.level;
      if (level == null) return;

      if (!await _wait(_demoIntro)) return;

      // The generator guarantees every level is constructively solvable, so
      // repeatedly taking any currently-escapable arrow always clears it.
      var pending = List<ArrowEntity>.of(bloc.state.arrows);
      while (!_disposed) {
        // Self-heal from resets or stray input between moves.
        if (bloc.state.status == GameStatus.playing) {
          pending = List<ArrowEntity>.of(bloc.state.arrows);
        }
        final id = getHint(
          arrows: pending,
          rows: level.rows,
          cols: level.cols,
        );
        if (id == null) break;

        setState(() => _handCell = pending.firstWhere((a) => a.id == id).head);
        if (!await _wait(_handTravel)) return;

        setState(() => _handPressed = true);
        if (!await _wait(_handPress)) return;
        if (!await _waitForPlaying(bloc)) return;

        setState(() {
          _handPressed = false;
          _tapSeq++;
        });
        bloc.add(ArrowTapped(id));
        pending = pending.where((a) => a.id != id).toList();

        if (!await _wait(_afterTap)) return;
      }

      setState(() => _handCell = null);

      // Loop the showcase so a single recording can capture several runs.
      if (!await _wait(_demoRestart)) return;
      bloc.add(GameStarted(level.id));
      if (!await _wait(const Duration(milliseconds: 300))) return;
    }
  }

  Future<void> _onHint(BuildContext context) async {
    final ads = sl<AdsService>();
    final earned = await ads.showRewardedForHint();
    if (!context.mounted || !earned) return;
    context.read<GameBloc>().add(const HintRequested());
  }

  @override
  Widget build(BuildContext context) {
    final demo = widget.demoMode;

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
                if (!demo) {
                  context.read<ProgressCubit>().refresh();
                  sl<AdsService>().maybeShowInterstitialOnLevelEnd();
                }
              } else if (state.status == GameStatus.lost) {
                audio.playLose();
                haptics.heavy();
                if (!demo) {
                  context.read<ProgressCubit>().refresh();
                  sl<AdsService>().maybeShowInterstitialOnLevelEnd();
                }
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
                                onBack: () =>
                                    context.go(demo ? '/' : '/levels'),
                                onReset: () => context
                                    .read<GameBloc>()
                                    .add(const ResetRequested()),
                                onHint: () => _onHint(context),
                                onSettings: () => context.go('/settings'),
                              ),
                            ),
                            // Space after hearts before playfield.
                            const SizedBox(height: 20),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: AppCard(
                                  elevation: 10,
                                  borderRadius: 22,
                                  padding: const EdgeInsets.all(12),
                                  // Let the demo hand hang past the board edge.
                                  clipBehavior:
                                      demo ? Clip.none : Clip.antiAlias,
                                  child: ExitAnimationGate(
                                    status: state.status,
                                    animationKey:
                                        state.lastRemovedArrowId == null
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
                                            enabled: !demo &&
                                                state.status ==
                                                    GameStatus.playing,
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
                                            overlayBuilder: !demo
                                                ? null
                                                : (context, boardSize) {
                                                    return DemoBoardOverlay(
                                                      boardSize: boardSize,
                                                      rows: level.rows,
                                                      cols: level.cols,
                                                      target: _handCell,
                                                      tapSeq: _tapSeq,
                                                      pressed: _handPressed,
                                                      palette:
                                                          colors.arrowPalette,
                                                      accent: colors.primary,
                                                      travel: _handTravel,
                                                    );
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
                              padding:
                                  const EdgeInsets.only(top: 4, bottom: 4),
                              child: Text(
                                level.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ),
                        if (demo && state.status == GameStatus.won)
                          Positioned.fill(
                            child: DemoConfetti(palette: colors.arrowPalette),
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
                  // Banner stays plain — no card/elevation around ads.
                  if (!demo) const BannerAdWidget(height: 50),
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
