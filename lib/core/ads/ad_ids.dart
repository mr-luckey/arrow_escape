import 'dart:io';

/// Google AdMob unit IDs.
///
/// Extra IDs in each list are **failover only**: if a load fails, the next ID
/// is tried. A successful unit is reused (AdMob auto-refresh for banners).
/// Do not cycle IDs after a fill — that looks like invalid traffic.
abstract final class AdIds {
  static String get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-5561438827097019~8896231206';
    }
    return 'ca-app-pub-3940256099942544~1458002511';
  }

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
    ];
  }

  static List<String> get interstitials {
    if (Platform.isAndroid) {
      return const [
        'ca-app-pub-5561438827097019/4317977938',
        'ca-app-pub-5561438827097019/1177523281',
        'ca-app-pub-5561438827097019/8864441617',
        'ca-app-pub-5561438827097019/1691814592',
        'ca-app-pub-5561438827097019/9378732923',
      ];
    }
    return const [
      'ca-app-pub-3940256099942544/4411468910',
    ];
  }

  static List<String> get rewardeds {
    if (Platform.isAndroid) {
      return const [
        'ca-app-pub-5561438827097019/2985694900',
        'ca-app-pub-5561438827097019/8065651254',
        'ca-app-pub-5561438827097019/9359531568',
        'ca-app-pub-5561438827097019/3700699131',
        'ca-app-pub-5561438827097019/4925196605',
      ];
    }
    return const [
      'ca-app-pub-3940256099942544/1712485313',
    ];
  }
}
