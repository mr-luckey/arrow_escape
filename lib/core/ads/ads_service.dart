import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../audio/audio_service.dart';
import '../config/ads_config.dart';
import '../network/network_guard.dart';

enum RewardedAdOutcome { earned, skipped, unavailable }

/// Central AdMob manager. Placement-based IDs. No waterfall. Offline = idle.
class AdsService {
  AdsService({
    required AudioService audio,
    AdsConfig config = appAdsConfig,
    NetworkGuard? network,
  })  : _audio = audio,
        _config = config,
        _network = network ?? NetworkGuard();

  final AudioService _audio;
  final AdsConfig _config;
  final NetworkGuard _network;

  bool _sdkInitialized = false;
  Completer<bool>? _sdkInitCompleter;

  /// Covers load+show for any fullscreen format so two ads never stack.
  bool _fullScreenBusy = false;
  bool _fullScreenShowing = false;
  DateTime? _lastFullScreenAt;
  int _levelEndsSinceInterstitial = 0;

  InterstitialAd? _interstitial;
  String? _interstitialPlacement;
  bool _interstitialLoading = false;

  RewardedAd? _rewarded;
  String? _rewardedPlacement;
  bool _rewardedLoading = false;

  int _interstitialAttempts = 0;
  int _rewardedAttempts = 0;
  Timer? _interstitialRetry;
  Timer? _rewardedRetry;

  bool get isReady => _sdkInitialized;
  bool get isOnline => _network.isOnline;
  bool get isFullScreenShowing => _fullScreenShowing;
  bool get isFullScreenBusy => _fullScreenBusy || _fullScreenShowing;
  bool get hasRewardedAd => _rewarded != null;
  bool get testMode => _config.testMode;
  NetworkGuard get network => _network;

  Future<void> init() async {
    await _network.start(
      onOnline: _onNetworkRestored,
      onOffline: _onNetworkLost,
    );
    if (_network.isOnline) {
      await _ensureSdk();
      if (_sdkInitialized) {
        unawaited(preloadInterstitial());
        unawaited(preloadRewarded());
      }
    }
  }

  Future<void> dispose() async {
    _cancelRetries();
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = null;
    _rewarded = null;
    await _network.dispose();
  }

  void _restoreAudio() {
    unawaited(_audio.onAdClosed());
  }

  bool _tryAcquireFullScreen() {
    if (_fullScreenBusy || _fullScreenShowing) return false;
    _fullScreenBusy = true;
    return true;
  }

  void _releaseFullScreen() {
    _fullScreenBusy = false;
  }

  /// Load a banner for one visible placement. Caller owns dispose.
  Future<BannerAd?> loadBanner({
    required String placement,
    required AdSize size,
  }) async {
    final unitId = _config.bannerUnitId(placement);
    if (unitId == null) return null;
    if (!await _canUseAds()) return null;
    try {
      final completer = Completer<BannerAd?>();
      final ad = BannerAd(
        adUnitId: unitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (loaded) {
            if (!completer.isCompleted) completer.complete(loaded as BannerAd);
          },
          onAdFailedToLoad: (failed, error) {
            debugPrint('Banner no-fill/fail [$placement]: $error');
            failed.dispose();
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
      await ad.load();
      return completer.future.timeout(
        _config.requestTimeout,
        onTimeout: () {
          ad.dispose();
          return null;
        },
      );
    } catch (error, stack) {
      debugPrint('loadBanner failed: $error\n$stack');
      return null;
    }
  }

  Future<void> preloadInterstitial({
    String placement = 'after_level_group',
  }) async {
    if (_interstitial != null && _interstitialPlacement == placement) return;
    if (_interstitialLoading) return;
    final unitId = _config.interstitialUnitId(placement);
    if (unitId == null) return;
    if (!await _canUseAds()) return;
    if (_interstitialAttempts > _config.maxRetries) return;

    _interstitialLoading = true;
    try {
      _interstitialRetry?.cancel();
      _interstitial?.dispose();
      _interstitial = null;
      final completer = Completer<InterstitialAd?>();
      await InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: completer.complete,
          onAdFailedToLoad: (error) {
            debugPrint('Interstitial no-fill/fail [$placement]: $error');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
      final ad = await completer.future.timeout(
        _config.requestTimeout,
        onTimeout: () => null,
      );
      if (ad == null) {
        _interstitialAttempts++;
        _scheduleInterstitialRetry(placement);
        return;
      }
      _interstitialAttempts = 0;
      _interstitialPlacement = placement;
      _interstitial = ad;
    } catch (error, stack) {
      debugPrint('preloadInterstitial failed: $error\n$stack');
    } finally {
      _interstitialLoading = false;
    }
  }

  /// Natural-break interstitial after level win/lose (cadence + interval).
  /// Does not wait for dismiss — overlay UI stays on screen.
  Future<bool> maybeShowInterstitialOnLevelEnd({
    String placement = 'after_level_group',
  }) async {
    _levelEndsSinceInterstitial++;
    if (_levelEndsSinceInterstitial < _config.levelsBetweenInterstitials) {
      return false;
    }
    final shown = await maybeShowInterstitialAtBreak(placement: placement);
    if (shown) _levelEndsSinceInterstitial = 0;
    return shown;
  }

  /// Navigation / section break. Honors frequency + fullscreen lock.
  /// Never during active puzzle logic — callers must only use at natural exits.
  /// Completes after the ad is dismissed (or immediately if not shown).
  Future<bool> maybeShowInterstitialAtBreak({
    String placement = 'section_transition',
  }) async {
    if (!_frequencyAllowsInterstitial()) {
      unawaited(preloadInterstitial(placement: placement));
      return false;
    }
    if (!_tryAcquireFullScreen()) return false;

    if (_interstitial == null) {
      await preloadInterstitial(placement: placement);
    }
    final ad = _interstitial;
    if (ad == null) {
      _releaseFullScreen();
      return false;
    }

    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _fullScreenShowing = true,
      onAdDismissedFullScreenContent: (shown) {
        _fullScreenShowing = false;
        _lastFullScreenAt = DateTime.now();
        shown.dispose();
        _interstitial = null;
        _releaseFullScreen();
        _restoreAudio();
        if (!done.isCompleted) done.complete(true);
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          unawaited(preloadInterstitial(placement: placement));
        });
      },
      onAdFailedToShowFullScreenContent: (shown, error) {
        debugPrint('Interstitial show failed: $error');
        _fullScreenShowing = false;
        shown.dispose();
        _interstitial = null;
        _releaseFullScreen();
        _restoreAudio();
        if (!done.isCompleted) done.complete(false);
      },
    );

    try {
      _interstitial = null;
      await _audio.pauseBgm();
      await ad.show();
      return done.future;
    } catch (error, stack) {
      debugPrint('showInterstitial failed: $error\n$stack');
      ad.dispose();
      _interstitial = null;
      _releaseFullScreen();
      _restoreAudio();
      return false;
    }
  }

  /// Show interstitial at a natural break (if allowed), then always continue.
  Future<void> runAfterInterstitialBreak({
    required String placement,
    required FutureOr<void> Function() onContinue,
  }) async {
    try {
      await maybeShowInterstitialAtBreak(placement: placement);
    } catch (error, stack) {
      debugPrint('interstitial break failed: $error\n$stack');
    }
    await onContinue();
  }

  Future<void> preloadRewarded({String placement = 'hint'}) async {
    if (_rewarded != null && _rewardedPlacement == placement) return;
    if (_rewardedLoading) return;
    final unitId = _config.rewardedUnitId(placement);
    if (unitId == null) return;
    if (!await _canUseAds()) return;
    if (_rewardedAttempts > _config.maxRetries) return;

    _rewardedLoading = true;
    try {
      _rewardedRetry?.cancel();
      _rewarded?.dispose();
      _rewarded = null;
      final completer = Completer<RewardedAd?>();
      await RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: completer.complete,
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded no-fill/fail [$placement]: $error');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
      final ad = await completer.future.timeout(
        _config.requestTimeout,
        onTimeout: () => null,
      );
      if (ad == null) {
        _rewardedAttempts++;
        _scheduleRewardedRetry(placement);
        return;
      }
      _rewardedAttempts = 0;
      _rewardedPlacement = placement;
      _rewarded = ad;
    } catch (error, stack) {
      debugPrint('preloadRewarded failed: $error\n$stack');
    } finally {
      _rewardedLoading = false;
    }
  }

  /// User-initiated only. Grant only when [RewardedAdOutcome.earned].
  /// Concurrent taps while loading/showing always return [unavailable].
  Future<RewardedAdOutcome> showRewarded({String placement = 'hint'}) async {
    if (!_network.isOnline) return RewardedAdOutcome.unavailable;
    if (!_tryAcquireFullScreen()) return RewardedAdOutcome.unavailable;

    try {
      if (_rewarded == null || _rewardedPlacement != placement) {
        await preloadRewarded(placement: placement);
      }
      final ad = _rewarded;
      if (ad == null) {
        _releaseFullScreen();
        return RewardedAdOutcome.unavailable;
      }

      final completer = Completer<RewardedAdOutcome>();
      var earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) => _fullScreenShowing = true,
        onAdDismissedFullScreenContent: (shown) {
          _fullScreenShowing = false;
          _lastFullScreenAt = DateTime.now();
          shown.dispose();
          _rewarded = null;
          _releaseFullScreen();
          _restoreAudio();
          if (!completer.isCompleted) {
            completer.complete(
              earned ? RewardedAdOutcome.earned : RewardedAdOutcome.skipped,
            );
          }
          Future<void>.delayed(const Duration(milliseconds: 800), () {
            unawaited(preloadRewarded(placement: placement));
          });
        },
        onAdFailedToShowFullScreenContent: (shown, error) {
          debugPrint('Rewarded show failed: $error');
          _fullScreenShowing = false;
          shown.dispose();
          _rewarded = null;
          _releaseFullScreen();
          _restoreAudio();
          if (!completer.isCompleted) {
            completer.complete(RewardedAdOutcome.unavailable);
          }
        },
      );

      _rewarded = null;
      await _audio.pauseBgm();
      await ad.show(
        onUserEarnedReward: (_, _) {
          earned = true;
        },
      );
      return completer.future;
    } catch (error, stack) {
      debugPrint('showRewarded failed: $error\n$stack');
      _rewarded?.dispose();
      _rewarded = null;
      _releaseFullScreen();
      _restoreAudio();
      return RewardedAdOutcome.unavailable;
    }
  }

  /// Back-compat for game hint flow. True only when reward was earned.
  Future<bool> showRewardedForHint() async {
    final outcome = await showRewarded(placement: 'hint');
    return outcome == RewardedAdOutcome.earned;
  }

  void _onNetworkRestored() {
    _interstitialAttempts = 0;
    _rewardedAttempts = 0;
    unawaited(() async {
      if (await _ensureSdk()) {
        unawaited(preloadInterstitial());
        unawaited(preloadRewarded());
      }
    }());
  }

  void _onNetworkLost() {
    _cancelRetries();
    // Drop cached fullscreen ads — they are useless / stale offline.
    _interstitial?.dispose();
    _interstitial = null;
    _rewarded?.dispose();
    _rewarded = null;
  }

  void _cancelRetries() {
    _interstitialRetry?.cancel();
    _rewardedRetry?.cancel();
    _interstitialRetry = null;
    _rewardedRetry = null;
  }

  Future<bool> _canUseAds() async {
    if (!_config.isEnabled) return false;
    if (!_network.isOnline) return false;
    return _ensureSdk();
  }

  Future<bool> _ensureSdk() async {
    if (_sdkInitialized) return true;
    if (!_network.isOnline || !_config.isEnabled) return false;

    // Single-flight init: never start a second initialize() while one is open.
    final existing = _sdkInitCompleter;
    if (existing != null) {
      try {
        return await existing.future.timeout(const Duration(seconds: 20));
      } on TimeoutException {
        // Init still running in background — callers retry later.
        return _sdkInitialized;
      }
    }

    final completer = Completer<bool>();
    _sdkInitCompleter = completer;
    try {
      // Do not wrap initialize itself in a short timeout — that abandons a
      // live SDK call and permanently blocks ads after a cold-start hang.
      await MobileAds.instance.initialize();
      if (_config.testMode) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: const ['EMULATOR'],
          ),
        );
      }
      _sdkInitialized = true;
      if (!completer.isCompleted) completer.complete(true);
      if (kDebugMode) {
        debugPrint(
          'Ads SDK ready (testMode=${_config.testMode}, '
          'forceTestAds=$kForceTestAds, '
          'appUnits=production, '
          'banner=${_config.bannerUnitId('home')})',
        );
      }
    } catch (error, stack) {
      debugPrint('MobileAds.initialize failed: $error\n$stack');
      _sdkInitialized = false;
      if (!completer.isCompleted) completer.complete(false);
      // Allow a later retry after a real failure.
      _sdkInitCompleter = null;
    }
    return _sdkInitialized;
  }

  bool _frequencyAllowsInterstitial() {
    final last = _lastFullScreenAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >=
        _config.minimumInterstitialInterval;
  }

  void _scheduleInterstitialRetry(String placement) {
    if (!_network.isOnline) return;
    if (_interstitialAttempts > _config.maxRetries) return;
    _interstitialRetry?.cancel();
    final delay = _config.retryBackoff * _interstitialAttempts;
    _interstitialRetry = Timer(delay, () {
      unawaited(preloadInterstitial(placement: placement));
    });
  }

  void _scheduleRewardedRetry(String placement) {
    if (!_network.isOnline) return;
    if (_rewardedAttempts > _config.maxRetries) return;
    _rewardedRetry?.cancel();
    final delay = _config.retryBackoff * _rewardedAttempts;
    _rewardedRetry = Timer(delay, () {
      unawaited(preloadRewarded(placement: placement));
    });
  }
}
