import 'dart:io';

/// Google sample / example ad unit IDs (safe for development).
///
/// Add as many unit IDs as you want to each list. The app tries them in order
/// until an ad is available (banners keep cycling forever).
abstract final class AdIds {
  static String get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544~3347511713';
    }
    return 'ca-app-pub-3940256099942544~1458002511';
  }

  /// Banner unit IDs — keep fetching forever, cycling this list.
  static List<String> get banners {
    if (Platform.isAndroid) {
      return const [
        'ca-app-pub-3940256099942544/6300978111',
        // Add more Android banner IDs below:
      ];
    }
    return const [
      'ca-app-pub-3940256099942544/2934735716',
      // Add more iOS banner IDs below:
    ];
  }

  /// Interstitial unit IDs — try until one loads, then stop.
  static List<String> get interstitials {
    if (Platform.isAndroid) {
      return const [
        'ca-app-pub-3940256099942544/1033173712',
        // Add more Android interstitial IDs below:
      ];
    }
    return const [
      'ca-app-pub-3940256099942544/4411468910',
      // Add more iOS interstitial IDs below:
    ];
  }

  /// Rewarded unit IDs — try until one loads, then stop.
  static List<String> get rewardeds {
    if (Platform.isAndroid) {
      return const [
        'ca-app-pub-3940256099942544/5224354917',
        // Add more Android rewarded IDs below:
      ];
    }
    return const [
      'ca-app-pub-3940256099942544/1712485313',
      // Add more iOS rewarded IDs below:
    ];
  }
}
