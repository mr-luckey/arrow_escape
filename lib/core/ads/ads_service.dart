import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

class AdsService {
  AdsService();

  bool _ready = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _winsSinceInterstitial = 0;

  Future<void> init() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    _ready = true;
    unawaited(preloadInterstitial());
    unawaited(preloadRewarded());
  }

  bool get isReady => _ready;

  Future<void> preloadInterstitial() async {
    if (!_ready) return;
    await InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial?.dispose();
          _interstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
              unawaited(preloadInterstitial());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
              unawaited(preloadInterstitial());
            },
          );
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
        },
      ),
    );
  }

  Future<void> preloadRewarded() async {
    if (!_ready) return;
    await RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded?.dispose();
          _rewarded = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewarded = null;
              unawaited(preloadRewarded());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewarded = null;
              unawaited(preloadRewarded());
            },
          );
        },
        onAdFailedToLoad: (_) {
          _rewarded = null;
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
    await ad.show();
  }

  /// Returns true if the user earned the reward (or ads unavailable → grant).
  Future<bool> showRewardedForHint() async {
    final ad = _rewarded;
    if (ad == null) {
      unawaited(preloadRewarded());
      // Don't block gameplay during ad load failures in example mode.
      return true;
    }
    _rewarded = null;
    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(earned);
        unawaited(preloadRewarded());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(true);
        unawaited(preloadRewarded());
      },
    );
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
