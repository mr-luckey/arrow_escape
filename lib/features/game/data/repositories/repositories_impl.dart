import '../../domain/entities/game_entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/level_asset_datasource.dart';
import '../datasources/progress_local_datasource.dart';

class LevelRepositoryImpl implements LevelRepository {
  LevelRepositoryImpl(this._dataSource);

  final LevelAssetDataSource _dataSource;

  @override
  Future<List<LevelEntity>> getAllLevels() => _dataSource.loadAll();

  @override
  Future<LevelEntity> getLevel(int id) => _dataSource.loadById(id);
}

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl(this._dataSource);

  final ProgressLocalDataSource _dataSource;

  @override
  Future<int> getHighestUnlocked() async => _dataSource.getHighestUnlocked();

  @override
  Future<void> unlockLevel(int levelId) => _dataSource.unlockLevel(levelId);

  @override
  Future<int> getStars(int levelId) async => _dataSource.getStars(levelId);

  @override
  Future<void> setStars(int levelId, int stars) =>
      _dataSource.setStars(levelId, stars);

  @override
  Future<Map<int, int>> getAllStars() async => _dataSource.getAllStars();
}
