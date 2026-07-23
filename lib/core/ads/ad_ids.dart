import 'dart:io';

/// Google AdMob unit IDs.
///
/// Put **as many IDs as you want** in each list. The app tries them in order:
/// - **Banner** — cycles forever (never stops fetching).
/// - **Interstitial / Rewarded** — waterfall until one loads, then stops;
///   after that ad is shown & closed, waterfall starts again.
///
/// Tip: keep Google sample IDs for debug; replace with your real IDs for release.
abstract final class AdIds {
  static String get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-5561438827097019~8896231206';
    }
    return 'ca-app-pub-3940256099942544~1458002511';
  }

  /// Banner unit IDs — continuous fetch / refresh forever.
  static List<String> get banners {
    if (Platform.isAndroid) {
      return const [
        'ca-app-pub-5561438827097019/1369094973',

        'ca-app-pub-5561438827097019/9056013307',
        'ca-app-pub-5561438827097019/8238021585',
        'ca-app-pub-5561438827097019/4485498893',
        'ca-app-pub-5561438827097019/6429849964',
      ];
    }
    return const [
      'ca-app-pub-3940256099942544/2934735716',
      // 'YOUR_IOS_BANNER_ID_2',
      // 'YOUR_IOS_BANNER_ID_3',
    ];
  }

  /// Interstitial unit IDs — try until one loads; never show two at once.
  static List<String> get interstitials {
    if (Platform.isAndroid) {
      return const [
        'ca-app-pub-5561438827097019/4317977938',
        'ca-app-pub-5561438827097019/1177523281',
        'ca-app-pub-5561438827097019/8864441617',
        'ca-app-pub-5561438827097019/1691814592',
        'ca-app-pub-5561438827097019/9378732923',
        // 'YOUR_ANDROID_INTERSTITIAL_ID_2',
        // 'YOUR_ANDROID_INTERSTITIAL_ID_3',
      ];
    }
    return const [
      'ca-app-pub-3940256099942544/4411468910',
      // 'YOUR_IOS_INTERSTITIAL_ID_2',
      // 'YOUR_IOS_INTERSTITIAL_ID_3',
    ];
  }

  /// Rewarded unit IDs — try until one loads; never show two at once.
  static List<String> get rewardeds {
    if (Platform.isAndroid) {
      return const [
        'ca-app-pub-5561438827097019/2985694900',
        'ca-app-pub-5561438827097019/8065651254',
        'ca-app-pub-5561438827097019/9359531568',
        'ca-app-pub-5561438827097019/3700699131',
        'ca-app-pub-5561438827097019/4925196605',
        // 'YOUR_ANDROID_REWARDED_ID_2',
        // 'YOUR_ANDROID_REWARDED_ID_3',
      ];
    }
    return const [
      'ca-app-pub-3940256099942544/1712485313',
      // 'YOUR_IOS_REWARDED_ID_2',
      // 'YOUR_IOS_REWARDED_ID_3',
    ];
  }
}
