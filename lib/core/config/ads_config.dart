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

/// Flip to `true` only for local QA with Google sample units.
/// Keep `false` for production (store builds and normal debug of prod IDs).
const bool kForceTestAds = false;

/// When true, Google sample ad units are used instead of production IDs.
bool get kUseTestAds => kForceTestAds;

/// AdMob-printed test device hash from this iPhone (debug console).
/// Registered only in [kDebugMode] so production unit IDs still serve
/// Google "Test Ad" creatives on this device — policy-safe, no sample units.
const List<String> kDebugAdMobTestDevices = [
  'bb5ac61ebee50a99e223c8a537fc5a62',
];

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

/// Production AdMob unit IDs (publisher `ca-app-pub-6497605679911497`).
///
/// App ID (Android/iOS): `ca-app-pub-6497605679911497~7575281768`
/// Five units per format = five named placements (not a no-fill waterfall).
///
/// Set [kForceTestAds] to `true` only for Google sample-unit QA.
AdsConfig get appAdsConfig => AdsConfig(
      isEnabled: true,
      testMode: kUseTestAds,
      bannerAdUnits: const [
        'ca-app-pub-6497605679911497/9289844804', // home
        'ca-app-pub-6497605679911497/6637604618', // game
        'ca-app-pub-6497605679911497/1026185289', // levels
        'ca-app-pub-6497605679911497/1844442934', // settings
        'ca-app-pub-6497605679911497/4175092805', // howto
      ],
      interstitialAdUnits: const [
        'ca-app-pub-6497605679911497/6084649857', // after_level_group
        'ca-app-pub-6497605679911497/4552523446', // open_settings
        'ca-app-pub-6497605679911497/2389394532', // leave_game
        'ca-app-pub-6497605679911497/1461299550', // section_transition
        'ca-app-pub-6497605679911497/5095448924', // spare / future placement
      ],
      rewardedAdUnits: const [
        'ca-app-pub-6497605679911497/9098273114', // hint
        'ca-app-pub-6497605679911497/5432334153',
        'ca-app-pub-6497605679911497/7118977031',
        'ca-app-pub-6497605679911497/5809317684',
        'ca-app-pub-6497605679911497/2670439447',
      ],
      bannerPlacements: const {
        'home': 0,
        'game': 1,
        'levels': 2,
        'settings': 3,
        'howto': 4,
      },
      interstitialPlacements: const {
        'after_level_group': 0,
        'open_settings': 1,
        'leave_game': 2,
        'section_transition': 3,
      },
      rewardedPlacements: const {
        'hint': 0,
      },
      minimumInterstitialInterval: const Duration(minutes: 2),
      levelsBetweenInterstitials: 2,
      maxRetries: 2,
      retryBackoff: const Duration(seconds: 30),
    );
