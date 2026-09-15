import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../di/injection.dart';
import '../network/network_guard.dart';
import 'ads_service.dart';

/// Bottom-anchored AdMob banner for [Scaffold.bottomNavigationBar].
///
/// Uses **standard** anchored adaptive sizing (full width, ~50–90dp) — the
/// classic phone banner height from AdMob Flutter/iOS docs. Avoids the
/// plugin's newer "large" adaptive API which can reserve up to ~150dp.
///
/// Root must be a fixed-height box so bottomNavigationBar cannot expand
/// and steal the scaffold body.
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

    // Intentionally NOT getLargeAnchoredAdaptiveBannerAdSize (50–150dp / ≤20%).
    // Standard anchored adaptive: full width, height 50–90dp / ≤15% of screen.
    // Still the correct native channel on iOS/Android; plugin only marked it
    // deprecated to push the taller "large" format.
    // ignore: deprecated_member_use
    return AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
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

    final adHeight = ad.size.height.toDouble();
    final adWidth = ad.size.width.toDouble();

    // Flush to the physical bottom — no safe-area gap under the banner.
    return SizedBox(
      width: double.infinity,
      height: adHeight,
      child: Center(
        child: SizedBox(
          width: adWidth,
          height: adHeight,
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
