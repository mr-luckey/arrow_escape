class NotificationMessage {
  const NotificationMessage({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  factory NotificationMessage.fromJson(Map<String, dynamic> json) {
    return NotificationMessage(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

enum NotificationRotationMode { alternate, sequential }

class NotificationConfig {
  const NotificationConfig({
    this.enabled = true,
    /// `true`  → only the short test burst (for QA).
    /// `false` → only production daily 17:00 / 21:00 (no test alerts).
    this.testMode = false,
    this.testNotificationCount = 5,
    this.testInterval = const Duration(seconds: 10),
    this.assetPath = 'assets/notifications/notifications.json',
    this.scheduleTimes = const ['17:00', '21:00'],
    this.rotationMode = NotificationRotationMode.alternate,
    this.daysToSchedule = 14,
    this.androidChannelId = 'daily_local',
    this.androidChannelName = 'ArrowPath reminders',
  });

  final bool enabled;
  final bool testMode;
  final int testNotificationCount;
  final Duration testInterval;
  final String assetPath;
  final List<String> scheduleTimes;
  final NotificationRotationMode rotationMode;
  final int daysToSchedule;
  final String androidChannelId;
  final String androidChannelName;
}

/// Production: daily 17:00 / 21:00. Set [testMode] true only for QA burst.
const appNotificationConfig = NotificationConfig(
  enabled: true,
  testMode: false,
  testNotificationCount: 5,
  testInterval: Duration(seconds: 10),
);
