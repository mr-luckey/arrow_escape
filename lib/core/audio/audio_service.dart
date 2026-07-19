import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Centralized BGM + SFX.
///
/// Important: SFX must NEVER steal audio focus from BGM. Each player gets its
/// own mixable [AudioContext], and after every SFX we confirm BGM is still up.
class AudioService {
  AudioService();

  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _hint = AudioPlayer();

  StreamSubscription<void>? _bgmCompleteSub;
  StreamSubscription<void>? _sfxCompleteSub;
  Timer? _bgmWatchdog;

  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _bgmStarted = false;
  bool _ready = false;
  bool _hintBeating = false;
  bool _bgmRestarting = false;
  bool _ignoreBgmComplete = false;

  static const _bgmVolume = 0.28;
  static const _sfxVolumeDefault = 0.45;
  static const _sfxVolumeEscape = 0.42; // normal — not too loud / not too quiet
  static const _hintVolume = 0.45;

  static AudioContext get _mixContext => AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );

  Future<void> init() async {
    if (kIsWeb) return;

    try {
      await AudioPlayer.global.setAudioContext(_mixContext);
    } catch (_) {}

    try {
      await _bgm.setAudioContext(_mixContext);
      await _sfx.setAudioContext(_mixContext);
      await _hint.setAudioContext(_mixContext);
    } catch (_) {}

    await _bgm.setPlayerMode(PlayerMode.mediaPlayer);
    await _sfx.setPlayerMode(PlayerMode.lowLatency);
    await _hint.setPlayerMode(PlayerMode.lowLatency);

    await _bgm.setReleaseMode(ReleaseMode.stop);
    await _bgm.setVolume(_bgmVolume);
    await _sfx.setReleaseMode(ReleaseMode.stop);
    await _sfx.setVolume(_sfxVolumeDefault);
    await _hint.setReleaseMode(ReleaseMode.stop);
    await _hint.setVolume(_hintVolume);

    _bgmCompleteSub = _bgm.onPlayerComplete.listen((_) {
      if (_ignoreBgmComplete) return;
      if (_musicEnabled && _bgmStarted) {
        unawaited(_replayBgm());
      }
    });

    // If a platform still ducks/pauses BGM when SFX ends, bring it back.
    _sfxCompleteSub = _sfx.onPlayerComplete.listen((_) {
      unawaited(_restoreBgmAfterSfx());
    });

    _bgmWatchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_ready || !_musicEnabled || !_bgmStarted || _bgmRestarting) return;
      if (_bgm.state != PlayerState.playing) {
        unawaited(_replayBgm());
      }
    });

    _ready = true;
  }

  void applySettings({required bool musicEnabled, required bool sfxEnabled}) {
    _musicEnabled = musicEnabled;
    _sfxEnabled = sfxEnabled;
    if (!_musicEnabled) {
      unawaited(_bgm.stop());
    } else if (_bgmStarted) {
      unawaited(ensureBgmPlaying(forceRestart: true));
    }
    if (!_sfxEnabled) {
      _hintBeating = false;
    }
  }

  Future<void> startBgm() async {
    if (!_ready || !_musicEnabled) return;
    _bgmStarted = true;
    await ensureBgmPlaying(forceRestart: true);
  }

  Future<void> _replayBgm() async {
    if (!_ready || !_musicEnabled || !_bgmStarted || _bgmRestarting) return;
    _bgmRestarting = true;
    try {
      _ignoreBgmComplete = true;
      try {
        await _bgm.stop();
      } finally {
        // Give the stop-complete event a tick to be ignored.
        await Future<void>.delayed(const Duration(milliseconds: 16));
        _ignoreBgmComplete = false;
      }
      await _bgm.setReleaseMode(ReleaseMode.stop);
      await _bgm.setVolume(_bgmVolume);
      await _bgm.play(AssetSource('audio/bgm_chill.wav'));
    } catch (_) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (_musicEnabled &&
            _bgmStarted &&
            _bgm.state != PlayerState.playing) {
          unawaited(_replayBgm());
        }
      });
    } finally {
      _bgmRestarting = false;
    }
  }

  Future<void> ensureBgmPlaying({bool forceRestart = false}) async {
    if (!_ready || !_musicEnabled || !_bgmStarted) return;
    try {
      if (!forceRestart && _bgm.state == PlayerState.playing) {
        await _bgm.setVolume(_bgmVolume);
        return;
      }
      if (!forceRestart && _bgm.state == PlayerState.paused) {
        await _bgm.resume();
        await _bgm.setVolume(_bgmVolume);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        if (_bgm.state == PlayerState.playing) return;
      }
      await _replayBgm();
    } catch (_) {}
  }

  Future<void> _restoreBgmAfterSfx() async {
    if (!_musicEnabled || !_bgmStarted) return;
    // Soft restore — resume if paused, else restart.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (_bgm.state == PlayerState.playing) {
      await _bgm.setVolume(_bgmVolume);
      return;
    }
    await ensureBgmPlaying(forceRestart: _bgm.state != PlayerState.paused);
  }

  Future<void> stopBgm() async {
    _bgmStarted = false;
    await _bgm.stop();
  }

  Future<void> pauseBgm() async {
    if (_bgm.state == PlayerState.playing) {
      await _bgm.pause();
    }
  }

  Future<void> resumeBgm() async {
    if (!_musicEnabled || !_bgmStarted) return;
    await ensureBgmPlaying(forceRestart: false);
  }

  Future<void> onAdClosed() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await ensureBgmPlaying(forceRestart: true);
  }

  Future<void> _playSfx(String asset, {double volume = _sfxVolumeDefault}) async {
    if (!_ready || !_sfxEnabled) return;
    try {
      // Duck BGM briefly instead of losing it.
      if (_bgm.state == PlayerState.playing) {
        await _bgm.setVolume(_bgmVolume * 0.35);
      }
      await _sfx.stop();
      await _sfx.setVolume(volume);
      await _sfx.play(AssetSource(asset));
      // Safety net: some devices never fire SFX complete.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 450), () {
          unawaited(_restoreBgmAfterSfx());
        }),
      );
    } catch (_) {
      unawaited(_restoreBgmAfterSfx());
    }
  }

  Future<void> playEscape() =>
      _playSfx('audio/sfx_escape.wav', volume: _sfxVolumeEscape);
  Future<void> playWrong() =>
      _playSfx('audio/sfx_wrong.wav', volume: 0.72);
  Future<void> playLose() =>
      _playSfx('audio/sfx_lose.wav', volume: 0.5);
  Future<void> playWin() =>
      _playSfx('audio/sfx_win.wav', volume: 0.55);

  Future<void> playHintThump() async {
    if (!_ready || !_sfxEnabled || !_hintBeating) return;
    try {
      if (_bgm.state == PlayerState.playing) {
        await _bgm.setVolume(_bgmVolume * 0.45);
      }
      await _hint.stop();
      await _hint.setVolume(_hintVolume);
      await _hint.play(AssetSource('audio/sfx_hint_thump.wav'));
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 220), () {
          unawaited(_restoreBgmAfterSfx());
        }),
      );
    } catch (_) {
      unawaited(_restoreBgmAfterSfx());
    }
  }

  void armHintBeat() {
    _hintBeating = _sfxEnabled;
  }

  Future<void> stopHintBeat() async {
    _hintBeating = false;
    try {
      await _hint.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _bgmWatchdog?.cancel();
    await _bgmCompleteSub?.cancel();
    await _sfxCompleteSub?.cancel();
    await stopHintBeat();
    await _bgm.dispose();
    await _sfx.dispose();
    await _hint.dispose();
  }
}
