import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../audio/audio_service.dart';
import 'ad_ids.dart';

class AdsService {
  AdsService(this._audio);

  final AudioService _audio;

  bool _ready = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _winsSinceInterstitial = 0;

  /// True while a waterfall load is in progress (avoids parallel fetches).
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  /// Guards against showing 2 fullscreen ads at once (double listener / double tap).
  bool _showingInterstitial = false;
  bool _showingRewarded = false;

  static const _retryAllFailedDelay = Duration(seconds: 3);
  static const _postShowCooldown = Duration(milliseconds: 800);

  Future<void> init() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    _ready = true;
    unawaited(preloadInterstitial());
    unawaited(preloadRewarded());
  }

  bool get isReady => _ready;

  void _restoreAudio() {
    unawaited(_audio.onAdClosed());
  }

  /// Waterfall: try each interstitial ID until one loads, then stop.
  /// After the ad is shown (or all IDs fail), fetching can start again.
  Future<void> preloadInterstitial() async {
    if (!_ready ||
        _interstitial != null ||
        _loadingInterstitial ||
        _showingInterstitial) {
      return;
    }
    final ids = AdIds.interstitials;
    if (ids.isEmpty) return;
    _loadingInterstitial = true;
    await _loadInterstitialAt(0, ids);
  }

  Future<void> _loadInterstitialAt(int index, List<String> ids) async {
    // Stop waterfall if we already have / are showing an ad.
    if (_interstitial != null || _showingInterstitial) {
      _loadingInterstitial = false;
      return;
    }
    if (index >= ids.length) {
      _loadingInterstitial = false;
      // All IDs failed — short pause, then try the list again.
      Future<void>.delayed(_retryAllFailedDelay, () {
        unawaited(preloadInterstitial());
      });
      return;
    }

    await InterstitialAd.load(
      adUnitId: ids[index],
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          // If a show started while this was loading, drop this fill.
          if (_showingInterstitial) {
            ad.dispose();
            return;
          }
          _interstitial?.dispose();
          _interstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
              _showingInterstitial = false;
              _restoreAudio();
              Future<void>.delayed(_postShowCooldown, () {
                unawaited(preloadInterstitial());
              });
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
              _showingInterstitial = false;
              _restoreAudio();
              Future<void>.delayed(_postShowCooldown, () {
                unawaited(preloadInterstitial());
              });
            },
          );
        },
        onAdFailedToLoad: (_) {
          // Next ID in the array — keep going until one fills.
          unawaited(_loadInterstitialAt(index + 1, ids));
        },
      ),
    );
  }

  /// Waterfall: try each rewarded ID until one loads, then stop.
  Future<void> preloadRewarded() async {
    if (!_ready ||
        _rewarded != null ||
        _loadingRewarded ||
        _showingRewarded) {
      return;
    }
    final ids = AdIds.rewardeds;
    if (ids.isEmpty) return;
    _loadingRewarded = true;
    await _loadRewardedAt(0, ids);
  }

  Future<void> _loadRewardedAt(int index, List<String> ids) async {
    if (_rewarded != null || _showingRewarded) {
      _loadingRewarded = false;
      return;
    }
    if (index >= ids.length) {
      _loadingRewarded = false;
      Future<void>.delayed(_retryAllFailedDelay, () {
        unawaited(preloadRewarded());
      });
      return;
    }

    await RewardedAd.load(
      adUnitId: ids[index],
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          if (_showingRewarded) {
            ad.dispose();
            return;
          }
          _rewarded?.dispose();
          _rewarded = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewarded = null;
              _showingRewarded = false;
              _restoreAudio();
              Future<void>.delayed(_postShowCooldown, () {
                unawaited(preloadRewarded());
              });
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewarded = null;
              _showingRewarded = false;
              _restoreAudio();
              Future<void>.delayed(_postShowCooldown, () {
                unawaited(preloadRewarded());
              });
            },
          );
        },
        onAdFailedToLoad: (_) {
          unawaited(_loadRewardedAt(index + 1, ids));
        },
      ),
    );
  }

  /// Show interstitial every 2 cleared / failed levels (example cadence).
  /// At most one interstitial on screen — never two.
  Future<void> maybeShowInterstitialOnLevelEnd() async {
    _winsSinceInterstitial++;
    if (_winsSinceInterstitial < 2) return;
    if (_showingInterstitial || _showingRewarded) return;

    final ad = _interstitial;
    if (ad == null) {
      unawaited(preloadInterstitial());
      return;
    }

    _winsSinceInterstitial = 0;
    _showingInterstitial = true;
    _interstitial = null;
    await _audio.pauseBgm();
    await ad.show();
  }

  /// Returns true if the user earned the reward (or ads unavailable → grant).
  /// At most one rewarded on screen — never two.
  Future<bool> showRewardedForHint() async {
    if (_showingRewarded || _showingInterstitial) return true;

    final ad = _rewarded;
    if (ad == null) {
      unawaited(preloadRewarded());
      return true;
    }

    _showingRewarded = true;
    _rewarded = null;
    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingRewarded = false;
        _restoreAudio();
        if (!completer.isCompleted) completer.complete(earned);
        Future<void>.delayed(_postShowCooldown, () {
          unawaited(preloadRewarded());
        });
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showingRewarded = false;
        _restoreAudio();
        if (!completer.isCompleted) completer.complete(true);
        Future<void>.delayed(_postShowCooldown, () {
          unawaited(preloadRewarded());
        });
      },
    );
    await _audio.pauseBgm();
    await ad.show(
      onUserEarnedReward: (_, reward) {
        earned = true;
      },
    );
    return completer.future;
  }

  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = null;
    _rewarded = null;
    _showingInterstitial = false;
    _showingRewarded = false;
  }
}
