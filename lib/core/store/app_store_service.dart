import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Play Store update checks + soft "Rate this app" prompts.
class AppStoreService {
  AppStoreService(this._prefs);

  final SharedPreferences _prefs;
  final InAppReview _inAppReview = InAppReview.instance;
  final Random _random = Random();

  static const _kLaunchCount = 'store_launch_count';
  static const _kLastRatePromptMs = 'store_last_rate_prompt_ms';
  static const _kRatedOrDeclined = 'store_rated_or_declined';
  static const _kNeverAsk = 'store_never_ask_rate';

  /// Minimum launches before a rate card can appear.
  static const minLaunchesBeforeRate = 3;

  /// Days to wait between rate prompts.
  static const rateCooldownDays = 7;

  /// Chance (0–1) to show the rate card when eligible.
  static const rateShowChance = 0.35;

  bool _sessionPrepared = false;
  bool _updateCheckedThisSession = false;
  bool _rateCheckedThisSession = false;

  /// Once per cold start: bump launch count.
  Future<void> prepareSession() async {
    if (_sessionPrepared) return;
    _sessionPrepared = true;
    final count = _prefs.getInt(_kLaunchCount) ?? 0;
    await _prefs.setInt(_kLaunchCount, count + 1);
  }

  /// Checks Play Store for an available update (Android only).
  /// Runs at most once per app session. Uses flexible update when possible.
  Future<void> checkForUpdate() async {
    if (_updateCheckedThisSession) return;
    _updateCheckedThisSession = true;
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e, st) {
      debugPrint('AppStoreService.checkForUpdate failed: $e\n$st');
    }
  }

  /// Returns true at most once per session when eligible + random roll passes.
  bool shouldShowRatePrompt() {
    if (_rateCheckedThisSession) return false;
    _rateCheckedThisSession = true;

    if (_prefs.getBool(_kNeverAsk) == true) return false;
    if (_prefs.getBool(_kRatedOrDeclined) == true) return false;

    final launches = _prefs.getInt(_kLaunchCount) ?? 0;
    if (launches < minLaunchesBeforeRate) return false;

    final lastMs = _prefs.getInt(_kLastRatePromptMs);
    if (lastMs != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
      if (elapsed < rateCooldownDays * Duration.millisecondsPerDay) {
        return false;
      }
    }

    return _random.nextDouble() < rateShowChance;
  }

  Future<void> markRatePromptShown() async {
    await _prefs.setInt(
      _kLastRatePromptMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> markRated() async {
    await _prefs.setBool(_kRatedOrDeclined, true);
  }

  Future<void> markDeclined() async {
    // Soft decline: cooldown only (already set in markRatePromptShown).
  }

  Future<void> markNeverAsk() async {
    await _prefs.setBool(_kNeverAsk, true);
  }

  /// Opens the native in-app review sheet, or Play Store listing as fallback.
  Future<void> requestReviewOrOpenStore() async {
    await markRated();
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        return;
      }
    } catch (e, st) {
      debugPrint('In-app review failed: $e\n$st');
    }
    await openStoreListing();
  }

  Future<void> openStoreListing() async {
    final info = await PackageInfo.fromPlatform();
    final packageName = info.packageName;
    final market = Uri.parse('market://details?id=$packageName');
    final web = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );

    try {
      if (await canLaunchUrl(market)) {
        await launchUrl(market, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    await launchUrl(web, mode: LaunchMode.externalApplication);
  }
}
