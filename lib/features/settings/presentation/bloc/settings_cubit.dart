import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;

  SettingsState copyWith({bool? soundEnabled, bool? hapticsEnabled}) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }

  @override
  List<Object?> get props => [soundEnabled, hapticsEnabled];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._prefs)
      : super(SettingsState(
          soundEnabled: _prefs.getBool(_soundKey) ?? true,
          hapticsEnabled: _prefs.getBool(_hapticsKey) ?? true,
        ));

  static const _soundKey = 'sound_enabled';
  static const _hapticsKey = 'haptics_enabled';

  final SharedPreferences _prefs;

  Future<void> toggleSound() async {
    final next = !state.soundEnabled;
    await _prefs.setBool(_soundKey, next);
    emit(state.copyWith(soundEnabled: next));
  }

  Future<void> toggleHaptics() async {
    final next = !state.hapticsEnabled;
    await _prefs.setBool(_hapticsKey, next);
    emit(state.copyWith(hapticsEnabled: next));
  }
}
