import '../entities/game_entities.dart';

abstract class LevelRepository {
  Future<List<LevelEntity>> getAllLevels();
  Future<LevelEntity> getLevel(int id);

  /// Showcase board played by the auto-demo, outside the normal progression.
  Future<LevelEntity> getDemoLevel();
}

abstract class ProgressRepository {
  Future<int> getHighestUnlocked();
  Future<void> unlockLevel(int levelId);
  Future<int> getStars(int levelId);
  Future<void> setStars(int levelId, int stars);
  Future<Map<int, int>> getAllStars();
}
