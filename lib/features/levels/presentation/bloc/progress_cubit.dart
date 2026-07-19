import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../game/domain/entities/game_entities.dart';
import '../../../game/domain/repositories/repositories.dart';

class ProgressState extends Equatable {
  const ProgressState({
    this.levels = const [],
    this.highestUnlocked = 1,
    this.stars = const {},
    this.loading = true,
  });

  final List<LevelEntity> levels;
  final int highestUnlocked;
  final Map<int, int> stars;
  final bool loading;

  ProgressState copyWith({
    List<LevelEntity>? levels,
    int? highestUnlocked,
    Map<int, int>? stars,
    bool? loading,
  }) {
    return ProgressState(
      levels: levels ?? this.levels,
      highestUnlocked: highestUnlocked ?? this.highestUnlocked,
      stars: stars ?? this.stars,
      loading: loading ?? this.loading,
    );
  }

  bool isUnlocked(int levelId) => levelId <= highestUnlocked;

  int starsFor(int levelId) => stars[levelId] ?? 0;

  @override
  List<Object?> get props => [levels, highestUnlocked, stars, loading];
}

class ProgressCubit extends Cubit<ProgressState> {
  ProgressCubit(this._levelRepository, this._progressRepository)
      : super(const ProgressState());

  final LevelRepository _levelRepository;
  final ProgressRepository _progressRepository;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final levels = await _levelRepository.getAllLevels();
    final unlocked = await _progressRepository.getHighestUnlocked();
    final stars = await _progressRepository.getAllStars();
    emit(ProgressState(
      levels: levels,
      highestUnlocked: unlocked,
      stars: stars,
      loading: false,
    ));
  }

  Future<void> refresh() => load();
}
