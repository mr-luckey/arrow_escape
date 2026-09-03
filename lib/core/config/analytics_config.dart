/// Project-specific analytics switches. Event names live here, not in widgets.
class AnalyticsConfig {
  const AnalyticsConfig({
    /// Disabled until `google-services.json` / `GoogleService-Info.plist` exist.
    this.enabled = false,
  });

  final bool enabled;

  static const eventLevelStarted = 'level_started';
  static const eventLevelCompleted = 'level_completed';
  static const eventLevelFailed = 'level_failed';
  static const eventLevelAbandoned = 'level_abandoned';
  static const eventHintUsed = 'hint_used';
  static const eventRewardClaimed = 'reward_claimed';
  static const eventDailyRewardClaimed = 'daily_reward_claimed';
  static const eventNotificationOpened = 'notification_opened';
  static const eventNotificationScheduled = 'notification_scheduled';
  static const eventRewardedAdCompleted = 'rewarded_ad_completed';
}

const appAnalyticsConfig = AnalyticsConfig(enabled: false);
