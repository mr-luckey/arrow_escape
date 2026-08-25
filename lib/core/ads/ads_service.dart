import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../audio/audio_service.dart';
import 'ad_ids.dart';
import 'ad_waterfall.dart';

class AdsService {
  AdsService(this._audio);

  final AudioService _audio;

  bool _ready = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _levelEndsSinceInterstitial = 0;

  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  bool _showingInterstitial = false;
  bool _showingRewarded = false;

  final _interstitialIds = AdWaterfall(AdIds.interstitials);
  final _rewardedIds = AdWaterfall(AdIds.rewardeds);

  int _interstitialBackoffSec = 30;
  int _rewardedBackoffSec = 30;

  /// Google: wait at least ~30s after a failed load before requesting again.
  static const _minRetry = Duration(seconds: 30);
  static const _maxRetry = Duration(seconds: 120);
  static const _showEveryNLevelEnds = 2;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await _gatherConsent();
      final canRequest = await ConsentInformation.instance.canRequestAds();
      if (!canRequest) return;

      await MobileAds.instance.initialize();
      _ready = true;
      unawaited(preloadInterstitial());
      unawaited(preloadRewarded());
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> _gatherConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!updated.isCompleted) updated.complete();
      },
      (_) {
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future;
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
  }

  Future<bool> privacyOptionsRequired() async {
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((_) {});
  }

  bool get isReady => _ready;

  void _restoreAudio() {
    unawaited(_audio.onAdClosed());
  }

  Duration _backoff(int seconds) {
    final d = Duration(seconds: seconds);
    if (d < _minRetry) return _minRetry;
    if (d > _maxRetry) return _maxRetry;
    return d;
  }

  Future<void> preloadInterstitial() async {
    if (!_ready ||
        _interstitial != null ||
        _loadingInterstitial ||
        _showingInterstitial ||
        _interstitialIds.isEmpty) {
      return;
    }
    _loadingInterstitial = true;
    _interstitialIds.beginLoad();
    _loadNextInterstitial();
  }

  void _loadNextInterstitial() {
    final unitId = _interstitialIds.next();
    if (unitId == null) {
      _loadingInterstitial = false;
      final wait = _backoff(_interstitialBackoffSec);
      _interstitialBackoffSec = (_interstitialBackoffSec * 2).clamp(30, 120);
      Future<void>.delayed(wait, () {
        unawaited(preloadInterstitial());
      });
      return;
    }

    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialBackoffSec = 30;
          _interstitialIds.markFilled(unitId);
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
              unawaited(preloadInterstitial());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
              _showingInterstitial = false;
              _restoreAudio();
              unawaited(preloadInterstitial());
            },
          );
        },
        onAdFailedToLoad: (_) {
          // Never retry immediately — Google flags rapid failed requests as IVT.
          Future<void>.delayed(_minRetry, () {
            if (!_ready || _interstitial != null || _showingInterstitial) {
              _loadingInterstitial = false;
              return;
            }
            _loadNextInterstitial();
          });
        },
      ),
    );
  }

  Future<void> preloadRewarded() async {
    if (!_ready ||
        _rewarded != null ||
        _loadingRewarded ||
        _showingRewarded ||
        _rewardedIds.isEmpty) {
      return;
    }
    _loadingRewarded = true;
    _rewardedIds.beginLoad();
    _loadNextRewarded();
  }

  void _loadNextRewarded() {
    final unitId = _rewardedIds.next();
    if (unitId == null) {
      _loadingRewarded = false;
      final wait = _backoff(_rewardedBackoffSec);
      _rewardedBackoffSec = (_rewardedBackoffSec * 2).clamp(30, 120);
      Future<void>.delayed(wait, () {
        unawaited(preloadRewarded());
      });
      return;
    }

    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewardedBackoffSec = 30;
          _rewardedIds.markFilled(unitId);
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
              unawaited(preloadRewarded());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewarded = null;
              _showingRewarded = false;
              _restoreAudio();
              unawaited(preloadRewarded());
            },
          );
        },
        onAdFailedToLoad: (_) {
          Future<void>.delayed(_minRetry, () {
            if (!_ready || _rewarded != null || _showingRewarded) {
              _loadingRewarded = false;
              return;
            }
            _loadNextRewarded();
          });
        },
      ),
    );
  }

  /// Interstitial at a natural break (level win/lose), every N completions.
  Future<void> maybeShowInterstitialOnLevelEnd() async {
    _levelEndsSinceInterstitial++;
    if (_levelEndsSinceInterstitial < _showEveryNLevelEnds) return;
    if (_showingInterstitial || _showingRewarded) return;

    final ad = _interstitial;
    if (ad == null) {
      unawaited(preloadInterstitial());
      return;
    }

    _levelEndsSinceInterstitial = 0;
    _showingInterstitial = true;
    _interstitial = null;
    await _audio.pauseBgm();
    await ad.show();
  }

  /// User-initiated rewarded. Grant if the ad cannot be shown (no fill).
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
        unawaited(preloadRewarded());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showingRewarded = false;
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
    _interstitial = null;
    _rewarded = null;
    _showingInterstitial = false;
    _showingRewarded = false;
  }
}
