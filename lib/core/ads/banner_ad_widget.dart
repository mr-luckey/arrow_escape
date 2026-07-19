import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// Fixed-height banner slot. Cycles through [AdIds.banners] forever until
/// disposed — after a fill it still keeps refreshing from the ID list.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key, this.height = 50});

  final double height;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _banner;
  bool _loaded = false;
  int _idIndex = 0;
  bool _disposed = false;
  Timer? _retryTimer;

  static const _retryDelay = Duration(milliseconds: 800);
  static const _refreshDelay = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _loadNext();
  }

  void _schedule(Duration delay, VoidCallback action) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_disposed && mounted) action();
    });
  }

  void _loadNext() {
    if (_disposed || kIsWeb) return;
    final ids = AdIds.banners;
    if (ids.isEmpty) return;

    final unitId = ids[_idIndex % ids.length];
    _idIndex++;

    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: unitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_disposed || !mounted) {
            ad.dispose();
            return;
          }
          final old = _banner;
          setState(() {
            _banner = ad as BannerAd;
            _loaded = true;
          });
          if (old != null && !identical(old, ad)) {
            old.dispose();
          }
          // Keep fetching forever — refresh from next ID shortly.
          _schedule(_refreshDelay, _loadNext);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (_disposed) return;
          // Keep trying the next ID; never stop for banners.
          _schedule(_retryDelay, _loadNext);
        },
      ),
    );

    // Reserve the slot while the first fill is loading.
    if (!_loaded) {
      _banner = banner;
    }
    banner.load();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: _loaded && banner != null
          ? AdWidget(ad: banner)
          : const ColoredBox(color: Color(0x22000000)),
    );
  }
}
