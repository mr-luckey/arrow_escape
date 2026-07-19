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

  /// Tries each interstitial ID in order until one loads, then stops.
  Future<void> preloadInterstitial() async {
    if (!_ready || _interstitial != null || _loadingInterstitial) return;
    final ids = AdIds.interstitials;
    if (ids.isEmpty) return;
    _loadingInterstitial = true;
    await _loadInterstitialAt(0, ids);
  }

  Future<void> _loadInterstitialAt(int index, List<String> ids) async {
    if (index >= ids.length) {
      _loadingInterstitial = false;
      return;
    }

    await InterstitialAd.load(
      adUnitId: ids[index],
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial?.dispose();
          _interstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
              _restoreAudio();
              unawaited(preloadInterstitial());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
              _restoreAudio();
              // Show failed — try remaining / restart waterfall for next chance.
              unawaited(preloadInterstitial());
            },
          );
        },
        onAdFailedToLoad: (_) {
          unawaited(_loadInterstitialAt(index + 1, ids));
        },
      ),
    );
  }

  /// Tries each rewarded ID in order until one loads, then stops.
  Future<void> preloadRewarded() async {
    if (!_ready || _rewarded != null || _loadingRewarded) return;
    final ids = AdIds.rewardeds;
    if (ids.isEmpty) return;
    _loadingRewarded = true;
    await _loadRewardedAt(0, ids);
  }

  Future<void> _loadRewardedAt(int index, List<String> ids) async {
    if (index >= ids.length) {
      _loadingRewarded = false;
      return;
    }

    await RewardedAd.load(
      adUnitId: ids[index],
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded?.dispose();
          _rewarded = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewarded = null;
              _restoreAudio();
              unawaited(preloadRewarded());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewarded = null;
              _restoreAudio();
              unawaited(preloadRewarded());
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
  Future<void> maybeShowInterstitialOnLevelEnd() async {
    _winsSinceInterstitial++;
    if (_winsSinceInterstitial < 2) return;
    final ad = _interstitial;
    if (ad == null) {
      unawaited(preloadInterstitial());
      return;
    }
    _winsSinceInterstitial = 0;
    _interstitial = null;
    await _audio.pauseBgm();
    await ad.show();
  }

  /// Returns true if the user earned the reward (or ads unavailable → grant).
  Future<bool> showRewardedForHint() async {
    final ad = _rewarded;
    if (ad == null) {
      unawaited(preloadRewarded());
      return true;
    }
    _rewarded = null;
    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _restoreAudio();
        if (!completer.isCompleted) completer.complete(earned);
        unawaited(preloadRewarded());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _restoreAudio();
        if (!completer.isCompleted) completer.complete(true);
        unawaited(preloadRewarded());
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
  }
}
