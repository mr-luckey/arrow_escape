import 'package:shared_preferences/shared_preferences.dart';

class ProgressLocalDataSource {
  ProgressLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const _unlockedKey = 'highest_unlocked';
  static const _starsPrefix = 'stars_';

  int getHighestUnlocked() => _prefs.getInt(_unlockedKey) ?? 1;

  Future<void> unlockLevel(int levelId) async {
    final current = getHighestUnlocked();
    if (levelId > current) {
      await _prefs.setInt(_unlockedKey, levelId);
    }
  }

  int getStars(int levelId) => _prefs.getInt('$_starsPrefix$levelId') ?? 0;

  Future<void> setStars(int levelId, int stars) async {
    final current = getStars(levelId);
    if (stars > current) {
      await _prefs.setInt('$_starsPrefix$levelId', stars);
    }
  }

  Map<int, int> getAllStars() {
    final result = <int, int>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_starsPrefix)) {
        final id = int.tryParse(key.substring(_starsPrefix.length));
        if (id != null) {
          result[id] = _prefs.getInt(key) ?? 0;
        }
      }
    }
    return result;
  }
}
