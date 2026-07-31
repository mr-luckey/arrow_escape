import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'level_tunes.dart';

/// Centralized BGM + SFX + the per-level arrow melody.
///
/// Important: SFX must NEVER steal audio focus from BGM. Each player gets its
/// own mixable [AudioContext], and after every SFX we confirm BGM is still up.
class AudioService {
  AudioService();

  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _hint = AudioPlayer();

  /// Arrow notes rotate through a small pool so a note keeps ringing while the
  /// next one is struck — a single player would cut every note short.
  static const int _notePlayerCount = 4;
  final List<AudioPlayer> _notes = List.generate(
    _notePlayerCount,
    (_) => AudioPlayer(),
    growable: false,
  );

  /// Only ever used to pull note samples into the platform's sound cache.
  final AudioPlayer _noteWarmup = AudioPlayer();

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

  List<int> _tune = const [];
  int _tuneLevelId = -1;
  int _noteCursor = 0;

  static const _bgmVolume = 0.28;
  static const _sfxVolumeDefault = 0.45;
  static const _hintVolume = 0.45;
  static const _noteVolume = 0.55;

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
      for (final note in _notes) {
        await note.setAudioContext(_mixContext);
      }
      await _noteWarmup.setAudioContext(_mixContext);
    } catch (_) {}

    await _bgm.setPlayerMode(PlayerMode.mediaPlayer);
    await _sfx.setPlayerMode(PlayerMode.lowLatency);
    await _hint.setPlayerMode(PlayerMode.lowLatency);

    // Looping natively avoids the audible gap of a stop/replay cycle. The
    // completion listener below stays as a fallback for platforms that ignore
    // the loop flag.
    await _bgm.setReleaseMode(ReleaseMode.loop);
    await _bgm.setVolume(_bgmVolume);
    await _sfx.setReleaseMode(ReleaseMode.stop);
    await _sfx.setVolume(_sfxVolumeDefault);
    await _hint.setReleaseMode(ReleaseMode.stop);
    await _hint.setVolume(_hintVolume);

    for (final note in _notes) {
      await note.setPlayerMode(PlayerMode.lowLatency);
      // Must not be `release`, or every note would be evicted from the
      // platform sound cache as soon as it is stopped.
      await note.setReleaseMode(ReleaseMode.stop);
      await note.setVolume(_noteVolume);
    }
    await _noteWarmup.setPlayerMode(PlayerMode.lowLatency);
    await _noteWarmup.setReleaseMode(ReleaseMode.stop);
    await _noteWarmup.setVolume(0);

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

    if (_tune.isNotEmpty) {
      unawaited(_preloadTune(_tune));
    }
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
      await _bgm.setReleaseMode(ReleaseMode.loop);
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
    // Only undo the ducking, and resume if the platform paused us. Restarting
    // here would throw the track back to its beginning after a sound effect —
    // the watchdog already covers genuinely dead playback.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (_bgm.state == PlayerState.playing) {
      await _bgm.setVolume(_bgmVolume);
      return;
    }
    if (_bgm.state == PlayerState.paused) {
      await ensureBgmPlaying();
    }
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

  // --- Per-level arrow melody ---

  /// Selects the tune for [levelId] and pulls its samples into the platform
  /// sound cache, so the very first arrow sounds as instant as the rest.
  void prepareLevelTune(int levelId) {
    if (_tuneLevelId == levelId && _tune.isNotEmpty) return;
    _tuneLevelId = levelId;
    _tune = LevelTunes.forLevel(levelId);
    _noteCursor = 0;
    unawaited(_preloadTune(_tune));
  }

  Future<void> _preloadTune(List<int> tune) async {
    if (!_ready) return;
    for (final midi in tune.toSet()) {
      if (!identical(tune, _tune)) return;
      try {
        await _noteWarmup
            .setSource(AssetSource(LevelTunes.assetFor(midi)))
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  /// Plays note [index] of the current level's tune (wrapping when the tune is
  /// shorter than the level). Deliberately does not duck the music: the notes
  /// share its key, so they layer instead of clashing.
  Future<void> playArrowNote({required int levelId, required int index}) async {
    if (!_ready || !_sfxEnabled) return;
    if (_tuneLevelId != levelId || _tune.isEmpty) {
      prepareLevelTune(levelId);
    }
    final tune = _tune;
    if (tune.isEmpty) return;

    final midi = tune[index.abs() % tune.length];
    final player = _notes[_noteCursor];
    _noteCursor = (_noteCursor + 1) % _notes.length;

    try {
      // A stopped player is required before replaying: otherwise the low
      // latency backend resumes the previous stream instead of striking again.
      await player.stop();
      await player.play(AssetSource(LevelTunes.assetFor(midi)));
    } catch (_) {}
  }

  // --- One-shot effects ---

  Future<void> _playSfx(String asset, {double volume = _sfxVolumeDefault}) async {
    if (!_ready || !_sfxEnabled) return;
    try {
      // Duck BGM briefly instead of losing it — not awaited, so the effect is
      // not delayed by a round trip to the music player.
      if (_bgm.state == PlayerState.playing) {
        unawaited(_bgm.setVolume(_bgmVolume * 0.35));
      }
      await _sfx.stop();
      await _sfx.play(AssetSource(asset), volume: volume);
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

  Future<void> playWrong() => _playSfx('audio/sfx_wrong.wav', volume: 0.72);
  Future<void> playLose() => _playSfx('audio/sfx_lose.wav', volume: 0.5);
  Future<void> playWin() => _playSfx('audio/sfx_win.wav', volume: 0.55);

  /// The hint heartbeat repeats every few hundred ms, so it must not duck the
  /// music — that made the background track pump up and down continuously.
  Future<void> playHintThump() async {
    if (!_ready || !_sfxEnabled || !_hintBeating) return;
    try {
      await _hint.stop();
      await _hint.play(AssetSource('audio/sfx_hint_thump.wav'),
          volume: _hintVolume);
    } catch (_) {}
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
    for (final note in _notes) {
      await note.dispose();
    }
    await _noteWarmup.dispose();
  }
}
