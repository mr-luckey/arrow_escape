import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ad_waterfall.dart';

/// One on-screen banner placement. Loads once; AdMob refreshes the same unit.
/// Extra IDs are used only when a load fails.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key, this.height = 50});

  final double height;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget>
    with WidgetsBindingObserver {
  BannerAd? _banner;
  bool _loaded = false;
  bool _disposed = false;
  bool _loading = false;
  Timer? _retryTimer;
  int _backoffSec = 30;
  late final AdWaterfall _ids = AdWaterfall(AdIds.banners);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoad());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_loaded &&
        !_loading &&
        _banner == null) {
      _startLoad();
    }
  }

  void _startLoad() {
    if (_disposed || kIsWeb || _loading || _loaded) return;
    if (_ids.isEmpty) return;
    _ids.beginLoad();
    _loadNext();
  }

  void _loadNext() {
    if (_disposed || kIsWeb || _loaded) return;

    final unitId = _ids.next();
    if (unitId == null) {
      _loading = false;
      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(seconds: _backoffSec), () {
        if (!_disposed && mounted && !_loaded) {
          _backoffSec = (_backoffSec * 2).clamp(30, 120);
          _startLoad();
        }
      });
      return;
    }

    _loading = true;
    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: unitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _loading = false;
          if (_disposed || !mounted) {
            ad.dispose();
            return;
          }
          _ids.markFilled(unitId);
          _backoffSec = 30;
          final old = _banner;
          setState(() {
            _banner = ad as BannerAd;
            _loaded = true;
          });
          if (old != null && !identical(old, ad)) {
            old.dispose();
          }
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _loading = false;
          if (_disposed) return;
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 30), () {
            if (!_disposed && mounted && !_loaded) _loadNext();
          });
        },
      ),
    );
    banner.load();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
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
