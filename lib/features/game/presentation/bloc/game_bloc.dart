import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/game_entities.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/game_usecases.dart';

// --- Events ---

sealed class GameEvent extends Equatable {
  const GameEvent();
  @override
  List<Object?> get props => [];
}

class GameStarted extends GameEvent {
  const GameStarted(this.levelId);
  final int levelId;
  @override
  List<Object?> get props => [levelId];
}

class ArrowTapped extends GameEvent {
  const ArrowTapped(this.arrowId);
  final String arrowId;
  @override
  List<Object?> get props => [arrowId];
}

class UndoRequested extends GameEvent {
  const UndoRequested();
}

class ResetRequested extends GameEvent {
  const ResetRequested();
}

class HintRequested extends GameEvent {
  const HintRequested();
}

class AnimationCompleted extends GameEvent {
  const AnimationCompleted();
}

// --- State ---

enum GameStatus { loading, playing, animating, won, lost, error }

class GameSnapshot extends Equatable {
  const GameSnapshot({
    required this.arrows,
    required this.hearts,
  });

  final List<ArrowEntity> arrows;
  final int hearts;

  @override
  List<Object?> get props => [arrows, hearts];
}

class GameState extends Equatable {
  const GameState({
    this.status = GameStatus.loading,
    this.level,
    this.arrows = const [],
    this.hearts = 3,
    this.hintArrowId,
    this.lastRemovedArrowId,
    this.lastFailedArrowId,
    this.undoStack = const [],
    this.errorMessage,
    this.moveCount = 0,
  });

  final GameStatus status;
  final LevelEntity? level;
  final List<ArrowEntity> arrows;
  final int hearts;
  final String? hintArrowId;
  final String? lastRemovedArrowId;
  final String? lastFailedArrowId;
  final List<GameSnapshot> undoStack;
  final String? errorMessage;
  final int moveCount;

  int get maxHearts => level?.hearts ?? 3;

  /// 3 stars if no hearts lost, 2 if one lost, 1 if two lost.
  int get earnedStars {
    final lost = maxHearts - hearts;
    if (lost <= 0) return 3;
    if (lost == 1) return 2;
    return 1;
  }

  GameState copyWith({
    GameStatus? status,
    LevelEntity? level,
    List<ArrowEntity>? arrows,
    int? hearts,
    String? hintArrowId,
    bool clearHint = false,
    String? lastRemovedArrowId,
    bool clearRemoved = false,
    String? lastFailedArrowId,
    bool clearFailed = false,
    List<GameSnapshot>? undoStack,
    String? errorMessage,
    int? moveCount,
  }) {
    return GameState(
      status: status ?? this.status,
      level: level ?? this.level,
      arrows: arrows ?? this.arrows,
      hearts: hearts ?? this.hearts,
      hintArrowId: clearHint ? null : (hintArrowId ?? this.hintArrowId),
      lastRemovedArrowId:
          clearRemoved ? null : (lastRemovedArrowId ?? this.lastRemovedArrowId),
      lastFailedArrowId:
          clearFailed ? null : (lastFailedArrowId ?? this.lastFailedArrowId),
      undoStack: undoStack ?? this.undoStack,
      errorMessage: errorMessage,
      moveCount: moveCount ?? this.moveCount,
    );
  }

  @override
  List<Object?> get props => [
        status,
        level,
        arrows,
        hearts,
        hintArrowId,
        lastRemovedArrowId,
        lastFailedArrowId,
        undoStack,
        errorMessage,
        moveCount,
      ];
}

// --- Bloc ---

class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc({
    required LevelRepository levelRepository,
    required ProgressRepository progressRepository,
    required ApplyMoveUseCase applyMove,
    required GetHintUseCase getHint,
  })  : _levelRepository = levelRepository,
        _progressRepository = progressRepository,
        _applyMove = applyMove,
        _getHint = getHint,
        super(const GameState()) {
    on<GameStarted>(_onStarted);
    on<ArrowTapped>(_onTapped);
    on<UndoRequested>(_onUndo);
    on<ResetRequested>(_onReset);
    on<HintRequested>(_onHint);
    on<AnimationCompleted>(_onAnimationCompleted);
  }

  final LevelRepository _levelRepository;
  final ProgressRepository _progressRepository;
  final ApplyMoveUseCase _applyMove;
  final GetHintUseCase _getHint;

  Future<void> _onStarted(GameStarted event, Emitter<GameState> emit) async {
    emit(const GameState(status: GameStatus.loading));
    try {
      final level = await _levelRepository.getLevel(event.levelId);
      emit(GameState(
        status: GameStatus.playing,
        level: level,
        arrows: List.of(level.arrows),
        hearts: level.hearts,
      ));
    } catch (e) {
      emit(GameState(
        status: GameStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onTapped(ArrowTapped event, Emitter<GameState> emit) async {
    final current = state;
    if (current.status != GameStatus.playing || current.level == null) return;
    if (!current.arrows.any((a) => a.id == event.arrowId)) return;

    final snapshot = GameSnapshot(
      arrows: List.of(current.arrows),
      hearts: current.hearts,
    );

    final result = _applyMove(
      arrowId: event.arrowId,
      arrows: current.arrows,
      rows: current.level!.rows,
      cols: current.level!.cols,
      hearts: current.hearts,
    );

    if (result.success) {
      // Keep arrow on board during exit animation; drop it when animation ends.
      emit(current.copyWith(
        status: GameStatus.animating,
        lastRemovedArrowId: result.removedArrowId,
        clearFailed: true,
        clearHint: true,
        undoStack: [...current.undoStack, snapshot],
        moveCount: current.moveCount + 1,
      ));
    } else {
      final nextHearts = result.hearts;
      emit(current.copyWith(
        hearts: nextHearts,
        lastFailedArrowId: event.arrowId,
        clearRemoved: true,
        clearHint: true,
        undoStack: [...current.undoStack, snapshot],
        moveCount: current.moveCount + 1,
        status: nextHearts <= 0 ? GameStatus.lost : GameStatus.playing,
      ));
    }
  }

  void _onUndo(UndoRequested event, Emitter<GameState> emit) {
    if (state.undoStack.isEmpty) return;
    if (state.status != GameStatus.playing &&
        state.status != GameStatus.lost) {
      return;
    }
    final stack = List<GameSnapshot>.of(state.undoStack);
    final prev = stack.removeLast();
    emit(state.copyWith(
      status: GameStatus.playing,
      arrows: prev.arrows,
      hearts: prev.hearts,
      undoStack: stack,
      clearHint: true,
      clearRemoved: true,
      clearFailed: true,
    ));
  }

  Future<void> _onReset(ResetRequested event, Emitter<GameState> emit) async {
    final id = state.level?.id;
    if (id == null) return;
    add(GameStarted(id));
  }

  void _onHint(HintRequested event, Emitter<GameState> emit) {
    if (state.status != GameStatus.playing || state.level == null) return;
    final id = _getHint(
      arrows: state.arrows,
      rows: state.level!.rows,
      cols: state.level!.cols,
    );
    emit(state.copyWith(hintArrowId: id, clearHint: id == null));
  }

  Future<void> _onAnimationCompleted(
    AnimationCompleted event,
    Emitter<GameState> emit,
  ) async {
    if (state.status != GameStatus.animating) return;

    final removedId = state.lastRemovedArrowId;
    final nextArrows = removedId == null
        ? state.arrows
        : state.arrows.where((a) => a.id != removedId).toList();

    if (nextArrows.isEmpty) {
      final level = state.level!;
      final stars = state.earnedStars;
      await _progressRepository.setStars(level.id, stars);
      await _progressRepository.unlockLevel(level.id + 1);
      emit(state.copyWith(
        status: GameStatus.won,
        arrows: nextArrows,
        clearRemoved: true,
      ));
    } else {
      emit(state.copyWith(
        status: GameStatus.playing,
        arrows: nextArrows,
        clearRemoved: true,
      ));
    }
  }
}
