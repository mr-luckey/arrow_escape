import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../config/notification_config.dart';

typedef NotificationTapCallback = void Function(String? payload);

/// Fully offline local notifications. No internet. No FCM.
///
/// Play Store safe: never uses `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` /
/// exact alarm APIs. Schedules with [AndroidScheduleMode.inexactAllowWhileIdle]
/// only so delivery still works after app kill without the restricted permission.
///
/// - [NotificationConfig.testMode] == true  → only the short test burst
/// - [NotificationConfig.testMode] == false → only daily 17:00 / 21:00 rotation
class LocalNotificationService {
  LocalNotificationService({
    NotificationConfig config = appNotificationConfig,
    FlutterLocalNotificationsPlugin? plugin,
    SharedPreferences? prefs,
    this.onTap,
  })  : _config = config,
        _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _prefs = prefs;

  static const _fingerprintKey = 'local_notification_fingerprint_v2';
  static const _testIdBase = 9000;

  /// Inexact only — no Play Store exact-alarm declaration required.
  static const _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

  final NotificationConfig _config;
  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences? _prefs;
  final NotificationTapCallback? onTap;

  bool _initialized = false;

  Future<void> init() async {
    if (!_config.enabled || _initialized) return;
    try {
      tz_data.initializeTimeZones();
      await _setLocalTimezone().timeout(const Duration(seconds: 2));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin
          .initialize(
            settings: const InitializationSettings(android: android, iOS: ios),
            onDidReceiveNotificationResponse: (response) {
              onTap?.call(response.payload);
            },
          )
          .timeout(const Duration(seconds: 3));
      await _ensureAndroidChannel().timeout(const Duration(seconds: 2));
      _initialized = true;
    } catch (error, stack) {
      debugPrint('LocalNotificationService.init failed: $error\n$stack');
    }
  }

  Future<void> _setLocalTimezone() async {
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
      return;
    } catch (error) {
      debugPrint('Timezone lookup failed, using UTC: $error');
    }
    tz.setLocalLocation(tz.UTC);
  }

  Future<void> _ensureAndroidChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _config.androidChannelId,
        _config.androidChannelName,
        description: 'Local ArrowPath Out reminders (works offline)',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
  }

  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final androidOk = await android?.requestNotificationsPermission() ?? true;
      final iosOk = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
      return androidOk && iosOk;
    } catch (error, stack) {
      debugPrint('Notification permission failed: $error\n$stack');
      return false;
    }
  }

  /// Call once after UI is up. Fully offline. Survives app kill.
  /// Never requests exact-alarm permission (Play Store safe).
  Future<int> scheduleNotifications() async {
    if (!_config.enabled) return 0;
    await init();
    if (!_initialized) return 0;

    final allowed = await requestPermission();
    if (!allowed) {
      debugPrint('Notification permission denied — skipping schedule');
      return 0;
    }

    try {
      final messages = await _loadMessages();
      if (messages.isEmpty) return 0;

      // Test burst ONLY in test mode. Production never shows these.
      if (_config.testMode) {
        await _plugin.cancelAll();
        final count = await _scheduleTestBurst(messages);
        debugPrint(
          'TEST MODE: scheduled $count offline notifications '
          '(every ${_config.testInterval.inSeconds}s, inexact — no alarm permission).',
        );
        return count;
      }

      final fingerprint = await _fingerprint(messages);
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (prefs.getString(_fingerprintKey) == fingerprint) {
        final pending = await _plugin.pendingNotificationRequests();
        if (pending.isNotEmpty) return pending.length;
      }

      await _plugin.cancelAll();
      final count = await _scheduleUpcoming(messages);
      await prefs.setString(_fingerprintKey, fingerprint);
      debugPrint(
        'PROD: scheduled $count daily local notifications '
        '(offline, inexact — no alarm permission).',
      );
      return count;
    } catch (error, stack) {
      debugPrint('scheduleNotifications failed: $error\n$stack');
      return 0;
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.remove(_fingerprintKey);
    } catch (error, stack) {
      debugPrint('cancelAll notifications failed: $error\n$stack');
    }
  }

  Future<List<NotificationMessage>> _loadMessages() async {
    final raw = await rootBundle.loadString(_config.assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['notifications'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NotificationMessage.fromJson)
        .where((m) => m.id.isNotEmpty && m.title.isNotEmpty)
        .toList();
  }

  NotificationDetails _details({bool high = true}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _config.androidChannelId,
        _config.androidChannelName,
        channelDescription: 'Local ArrowPath Out reminders (works offline)',
        importance: high ? Importance.high : Importance.defaultImportance,
        priority: high ? Priority.high : Priority.defaultPriority,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime fire,
    required NotificationDetails details,
    String? payload,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: fire,
      notificationDetails: details,
      androidScheduleMode: _scheduleMode,
      payload: payload,
    );
  }

  /// Test-only burst. Offline + app-kill OK. No exact-alarm permission.
  Future<int> _scheduleTestBurst(List<NotificationMessage> messages) async {
    var scheduled = 0;
    final now = tz.TZDateTime.now(tz.local);
    final count = _config.testNotificationCount;
    for (var i = 0; i < count; i++) {
      final fire = now.add(_config.testInterval * (i + 1));
      final message = messages[i % messages.length];
      await _scheduleAt(
        id: _testIdBase + i,
        title: message.title,
        body: message.body,
        fire: fire,
        details: _details(),
        payload: message.id,
      );
      scheduled++;
    }
    return scheduled;
  }

  Future<int> _scheduleUpcoming(List<NotificationMessage> messages) async {
    var scheduled = 0;
    final now = tz.TZDateTime.now(tz.local);
    for (var day = 0; day < _config.daysToSchedule; day++) {
      final time = _timeForDay(day);
      if (time == null) continue;
      var fire = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      ).add(Duration(days: day));
      if (!fire.isAfter(now)) {
        if (day == 0) {
          fire = fire.add(Duration(days: _config.daysToSchedule));
        } else {
          continue;
        }
      }
      final message = messages[day % messages.length];
      await _scheduleAt(
        id: day + 1,
        title: message.title,
        body: message.body,
        fire: fire,
        details: _details(high: false),
        payload: message.id,
      );
      scheduled++;
    }
    return scheduled;
  }

  ({int hour, int minute})? _timeForDay(int dayIndex) {
    final times = _config.scheduleTimes;
    if (times.isEmpty) return null;
    final token = _config.rotationMode == NotificationRotationMode.alternate
        ? times[dayIndex % times.length]
        : times[0];
    final parts = token.split(':');
    if (parts.length != 2) return null;
    return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<String> _fingerprint(List<NotificationMessage> messages) async {
    String tzName;
    try {
      tzName = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      tzName = 'fallback';
    }
    return jsonEncode({
      'tz': tzName,
      'testMode': false,
      'times': _config.scheduleTimes,
      'mode': _config.rotationMode.name,
      'days': _config.daysToSchedule,
      'messages': messages
          .map((m) => {'id': m.id, 'title': m.title, 'body': m.body})
          .toList(),
    });
  }
}
