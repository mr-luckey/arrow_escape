import 'package:flutter/foundation.dart';

/// Official Google sample units. Used only when [AdsConfig.testMode] is true.
abstract final class GoogleTestAdUnits {
  static const androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const androidRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const iosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const iosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const iosRewarded = 'ca-app-pub-3940256099942544/1712485313';
}

/// Flip this to force Google test ad units (even outside debug).
/// Keep `false` for production.
const bool kForceTestAds = false;

/// Central AdMob configuration. Placement-based IDs — no waterfall.
class AdsConfig {
  const AdsConfig({
    this.isEnabled = true,
    this.testMode = false,
    this.bannerEnabled = true,
    this.interstitialEnabled = true,
    this.rewardedEnabled = true,
    this.bannerAdUnits = const [],
    this.interstitialAdUnits = const [],
    this.rewardedAdUnits = const [],
    this.bannerPlacements = const {'home': 0},
    this.interstitialPlacements = const {
      'after_level_group': 0,
      'open_settings': 1,
      'leave_game': 2,
      'section_transition': 3,
    },
    this.rewardedPlacements = const {'hint': 0},
    this.minimumInterstitialInterval = const Duration(minutes: 2),
    this.levelsBetweenInterstitials = 2,
    this.maxRetries = 2,
    this.retryBackoff = const Duration(seconds: 30),
    this.requestTimeout = const Duration(seconds: 10),
  });

  final bool isEnabled;
  final bool testMode;
  final bool bannerEnabled;
  final bool interstitialEnabled;
  final bool rewardedEnabled;

  final List<String> bannerAdUnits;
  final List<String> interstitialAdUnits;
  final List<String> rewardedAdUnits;

  final Map<String, int> bannerPlacements;
  final Map<String, int> interstitialPlacements;
  final Map<String, int> rewardedPlacements;

  final Duration minimumInterstitialInterval;
  final int levelsBetweenInterstitials;
  final int maxRetries;
  final Duration retryBackoff;
  final Duration requestTimeout;

  String? bannerUnitId(String placement) =>
      _unit(bannerAdUnits, bannerPlacements[placement], bannerEnabled);

  String? interstitialUnitId(String placement) => _unit(
        interstitialAdUnits,
        interstitialPlacements[placement],
        interstitialEnabled,
      );

  String? rewardedUnitId(String placement) =>
      _unit(rewardedAdUnits, rewardedPlacements[placement], rewardedEnabled);

  String? _unit(List<String> units, int? index, bool enabled) {
    if (!isEnabled || !enabled || index == null || index < 0) return null;
    if (testMode) return _testIdFor(units);
    if (index >= units.length) return null;
    final id = units[index].trim();
    return id.isEmpty ? null : id;
  }

  String _testIdFor(List<String> units) {
    if (identical(units, bannerAdUnits)) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? GoogleTestAdUnits.iosBanner
          : GoogleTestAdUnits.androidBanner;
    }
    if (identical(units, interstitialAdUnits)) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? GoogleTestAdUnits.iosInterstitial
          : GoogleTestAdUnits.androidInterstitial;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? GoogleTestAdUnits.iosRewarded
        : GoogleTestAdUnits.androidRewarded;
  }
}

/// Production AdMob unit IDs (publisher ca-app-pub-6619866004331477).
const appAdsConfig = AdsConfig(
  isEnabled: true,
  testMode: false,
  bannerAdUnits: [
    'ca-app-pub-6619866004331477/6639858678', // home
    'ca-app-pub-6619866004331477/5368078951', // game
    'ca-app-pub-6619866004331477/2902582192', // levels
    'ca-app-pub-6619866004331477/5153205313', // settings
    'ca-app-pub-6619866004331477/8260062109', // howto
  ],
  interstitialAdUnits: [
    'ca-app-pub-6619866004331477/5337173846', // after_level_group
    'ca-app-pub-6619866004331477/6065143605', // open_settings
    'ca-app-pub-6619866004331477/9373833225', // leave_game
    'ca-app-pub-6619866004331477/3671853905', // section_transition
    'ca-app-pub-6619866004331477/4024092174',
  ],
  rewardedAdUnits: [
    'ca-app-pub-6619866004331477/1397928839', // hint
    'ca-app-pub-6619866004331477/4320817091',
    'ca-app-pub-6619866004331477/7186653580',
    'ca-app-pub-6619866004331477/2337756780',
    'ca-app-pub-6619866004331477/8499735252',
  ],
  bannerPlacements: {
    'home': 0,
    'game': 1,
    'levels': 2,
    'settings': 3,
    'howto': 4,
  },
  interstitialPlacements: {
    'after_level_group': 0,
    'open_settings': 1,
    'leave_game': 2,
    'section_transition': 3,
  },
  rewardedPlacements: {
    'hint': 0,
  },
  minimumInterstitialInterval: Duration(minutes: 2),
  levelsBetweenInterstitials: 2,
  maxRetries: 2,
  retryBackoff: Duration(seconds: 30),
);
