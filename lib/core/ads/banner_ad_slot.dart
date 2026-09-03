import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../di/injection.dart';
import '../network/network_guard.dart';
import 'ads_service.dart';

/// Standard AdMob anchored adaptive banner for [Scaffold.bottomNavigationBar].
///
/// Critical: the root must be a fixed-height box. An expanding [Align] /
/// [Center] inside bottomNavigationBar steals the whole screen and makes
/// the body disappear.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({
    super.key,
    required this.placement,
    this.ads,
    this.size,
    this.refreshInterval = const Duration(seconds: 60),
  });

  final AdsService? ads;
  final String placement;
  final AdSize? size;
  final Duration refreshInterval;

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  Timer? _refreshTimer;
  StreamSubscription<bool>? _networkSub;
  int _loadGeneration = 0;
  Orientation? _orientation;

  AdsService get _ads => widget.ads ?? sl<AdsService>();
  NetworkGuard get _network => _ads.network;

  @override
  void initState() {
    super.initState();
    _networkSub = _network.onStatusChanged.listen(_onNetworkChanged);
    _scheduleRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MediaQuery.orientationOf(context);
    if (_orientation != next) {
      _orientation = next;
      unawaited(_load(force: true));
    }
  }

  void _onNetworkChanged(bool online) {
    if (!mounted) return;
    if (!online) {
      _clearAd();
      return;
    }
    unawaited(_load(force: true));
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (widget.refreshInterval <= Duration.zero) return;
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) {
      if (!mounted || !_network.isOnline) return;
      unawaited(_load(force: true));
    });
  }

  Future<AdSize?> _resolveSize() async {
    if (widget.size != null) return widget.size;
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0) return null;
    return AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    if (_loading && !force) return;
    if (!_network.isOnline) {
      _clearAd();
      return;
    }

    final generation = ++_loadGeneration;
    _loading = true;
    BannerAd? previous;
    try {
      final size = await _resolveSize();
      if (!mounted || generation != _loadGeneration) return;
      if (size == null) {
        _clearAd();
        return;
      }

      final ad = await _ads.loadBanner(
        placement: widget.placement,
        size: size,
      );
      if (!mounted || generation != _loadGeneration) {
        ad?.dispose();
        return;
      }

      previous = _ad;
      setState(() {
        _ad = ad;
        _loaded = ad != null;
      });
      previous?.dispose();
    } finally {
      if (generation == _loadGeneration) _loading = false;
    }
  }

  void _clearAd() {
    final old = _ad;
    if (_loaded || old != null) {
      setState(() {
        _ad = null;
        _loaded = false;
      });
    }
    old?.dispose();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    unawaited(_networkSub?.cancel() ?? Future<void>.value());
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final adHeight = ad.size.height.toDouble();
    final adWidth = ad.size.width.toDouble();

    // Fixed total height only — never let this expand into the body.
    return SizedBox(
      width: double.infinity,
      height: adHeight + bottomInset,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Center(
          child: SizedBox(
            width: adWidth,
            height: adHeight,
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
