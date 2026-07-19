import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/haptics/haptics_service.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
  });

  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;

  SettingsState copyWith({
    bool? soundEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }

  @override
  List<Object?> get props => [soundEnabled, musicEnabled, hapticsEnabled];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._prefs, this._audio, this._haptics)
      : super(SettingsState(
          soundEnabled: _prefs.getBool(_soundKey) ?? true,
          musicEnabled: _prefs.getBool(_musicKey) ?? true,
          // Default ON; rebuild if a previous session left it off accidentally.
          hapticsEnabled: _prefs.getBool(_hapticsKey) ?? true,
        )) {
    _audio.applySettings(
      musicEnabled: state.musicEnabled,
      sfxEnabled: state.soundEnabled,
    );
    _haptics.setEnabled(state.hapticsEnabled);
  }

  static const _soundKey = 'sound_enabled';
  static const _musicKey = 'music_enabled';
  static const _hapticsKey = 'haptics_enabled';

  final SharedPreferences _prefs;
  final AudioService _audio;
  final HapticsService _haptics;

  Future<void> toggleSound() async {
    final next = !state.soundEnabled;
    await _prefs.setBool(_soundKey, next);
    emit(state.copyWith(soundEnabled: next));
    _audio.applySettings(
      musicEnabled: state.musicEnabled,
      sfxEnabled: next,
    );
  }

  Future<void> toggleMusic() async {
    final next = !state.musicEnabled;
    await _prefs.setBool(_musicKey, next);
    emit(state.copyWith(musicEnabled: next));
    _audio.applySettings(
      musicEnabled: next,
      sfxEnabled: state.soundEnabled,
    );
    if (next) {
      await _audio.startBgm();
    } else {
      await _audio.stopBgm();
    }
  }

  Future<void> toggleHaptics() async {
    final next = !state.hapticsEnabled;
    await _prefs.setBool(_hapticsKey, next);
    _haptics.setEnabled(next);
    emit(state.copyWith(hapticsEnabled: next));
    if (next) {
      await _haptics.testPulse();
    }
  }
}
