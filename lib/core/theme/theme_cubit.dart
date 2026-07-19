import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

class ThemeCubit extends Cubit<AppColorSchemeId> {
  ThemeCubit(this._prefs)
      : super(_read(_prefs));

  static const _key = 'color_scheme';
  final SharedPreferences _prefs;

  static AppColorSchemeId _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    return AppColorSchemeId.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppColorSchemeId.sky,
    );
  }

  Future<void> setScheme(AppColorSchemeId id) async {
    await _prefs.setString(_key, id.name);
    emit(id);
  }

  void cycle() {
    final next = AppColorSchemeId
        .values[(state.index + 1) % AppColorSchemeId.values.length];
    setScheme(next);
  }
}
