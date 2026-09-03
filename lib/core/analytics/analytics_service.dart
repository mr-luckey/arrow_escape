import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/analytics_config.dart';

/// Central analytics facade. Never throws to callers. Never sends PII.
///
/// Requires Firebase platform files (`google-services.json` /
/// `GoogleService-Info.plist`). Until those exist, keep [AnalyticsConfig.enabled]
/// false — [init] stays a no-op and gameplay is unaffected.
class AnalyticsService {
  AnalyticsService({
    AnalyticsConfig config = appAnalyticsConfig,
    FirebaseAnalytics? analytics,
  })  : _config = config,
        _analyticsOverride = analytics;

  final AnalyticsConfig _config;
  final FirebaseAnalytics? _analyticsOverride;
  FirebaseAnalytics? _analytics;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    if (!_config.enabled) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _analytics = _analyticsOverride ?? FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _ready = true;
    } catch (error, stack) {
      _ready = false;
      debugPrint('Analytics init failed (Firebase not configured?): $error\n$stack');
    }
  }

  Future<void> logLevelStarted({
    int? levelNumber,
    String? difficulty,
    int? attemptNumber,
    String? source,
  }) {
    return logEvent(AnalyticsConfig.eventLevelStarted, {
      if (levelNumber != null) 'level_number': levelNumber,
      if (difficulty != null) 'difficulty': difficulty,
      if (attemptNumber != null) 'attempt_number': attemptNumber,
      if (source != null) 'source': source,
    });
  }

  Future<void> logLevelCompleted({
    int? levelNumber,
    String? difficulty,
    int? moves,
    int? timeSeconds,
    int? attemptNumber,
    String? source,
  }) {
    return logEvent(AnalyticsConfig.eventLevelCompleted, {
      if (levelNumber != null) 'level_number': levelNumber,
      if (difficulty != null) 'difficulty': difficulty,
      if (moves != null) 'moves': moves,
      if (timeSeconds != null) 'time_seconds': timeSeconds,
      if (attemptNumber != null) 'attempt_number': attemptNumber,
      if (source != null) 'source': source,
    });
  }

  Future<void> logLevelFailed({
    int? levelNumber,
    String? difficulty,
    int? moves,
    int? timeSeconds,
    int? attemptNumber,
    String? source,
  }) {
    return logEvent(AnalyticsConfig.eventLevelFailed, {
      if (levelNumber != null) 'level_number': levelNumber,
      if (difficulty != null) 'difficulty': difficulty,
      if (moves != null) 'moves': moves,
      if (timeSeconds != null) 'time_seconds': timeSeconds,
      if (attemptNumber != null) 'attempt_number': attemptNumber,
      if (source != null) 'source': source,
    });
  }

  Future<void> logLevelAbandoned({
    int? levelNumber,
    String? difficulty,
    String? source,
  }) {
    return logEvent(AnalyticsConfig.eventLevelAbandoned, {
      if (levelNumber != null) 'level_number': levelNumber,
      if (difficulty != null) 'difficulty': difficulty,
      if (source != null) 'source': source,
    });
  }

  Future<void> logHintUsed({int? levelNumber, String? source}) {
    return logEvent(AnalyticsConfig.eventHintUsed, {
      if (levelNumber != null) 'level_number': levelNumber,
      if (source != null) 'source': source,
    });
  }

  Future<void> logRewardClaimed({String? rewardType, String? source}) {
    return logEvent(AnalyticsConfig.eventRewardClaimed, {
      if (rewardType != null) 'reward_type': rewardType,
      if (source != null) 'source': source,
    });
  }

  Future<void> logNotificationOpened({
    String? notificationId,
    String? source,
  }) {
    return logEvent(AnalyticsConfig.eventNotificationOpened, {
      if (notificationId != null) 'notification_id': notificationId,
      if (source != null) 'source': source,
    });
  }

  Future<void> logNotificationScheduled({int? count, String? source}) {
    return logEvent(AnalyticsConfig.eventNotificationScheduled, {
      if (count != null) 'count': count,
      if (source != null) 'source': source,
    });
  }

  Future<void> logRewardedAdCompleted({String? placement, String? source}) {
    return logEvent(AnalyticsConfig.eventRewardedAdCompleted, {
      if (placement != null) 'placement': placement,
      if (source != null) 'source': source,
    });
  }

  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    if (!_config.enabled || !_ready) return;
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters == null ? null : _sanitize(parameters),
      );
    } catch (error, stack) {
      debugPrint('Analytics event "$name" failed: $error\n$stack');
    }
  }

  Map<String, Object> _sanitize(Map<String, Object> parameters) {
    const blocked = {
      'password',
      'email',
      'phone',
      'token',
      'auth',
      'payment',
      'card',
    };
    final out = <String, Object>{};
    for (final entry in parameters.entries) {
      final key = entry.key.toLowerCase();
      if (blocked.any(key.contains)) continue;
      final value = entry.value;
      if (value is String || value is num || value is bool) {
        out[entry.key] = value;
      } else {
        out[entry.key] = value.toString();
      }
    }
    return out;
  }
}
