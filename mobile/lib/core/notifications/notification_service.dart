import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Manages local notification scheduling for reminders.
///
/// Written against flutter_local_notifications v20.1.0, flutter_timezone v5,
/// timezone 0.10.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _timezoneReady = false;

  Future<void> init({
    void Function(String? payload)? onTap,
  }) async {
    if (_initialized) return;

    await _setupTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'reminder',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('done', 'Mark done'),
          ],
        ),
      ],
    );

    // v20: initialize takes a single `settings` named parameter.
    await _plugin.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        onTap?.call(response.payload);
      },
    );

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await android?.requestNotificationsPermission() ?? false;
      await android?.requestExactAlarmsPermission();
      return granted;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    if (!_initialized) return;
    if (!_timezoneReady) await _setupTimezone();
    if (when.isBefore(DateTime.now())) return;

    final scheduled = tz.TZDateTime.from(when, tz.local);

    final androidDetails = AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Notifications for scheduled reminders',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'reminder',
    );

    try {
      // v20: zonedSchedule is fully named-argument based.
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (error) {
      developer.log(
        'Failed to schedule notification $id',
        error: error,
        name: 'NotificationService',
      );
    }
  }

  Future<void> cancel(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> pending() async {
    if (!_initialized) return const [];
    return _plugin.pendingNotificationRequests();
  }

  Future<void> _setupTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      _timezoneReady = true;
    } catch (error) {
      developer.log(
        'Could not resolve device timezone; using UTC',
        error: error,
        name: 'NotificationService',
      );
      tz.setLocalLocation(tz.UTC);
      _timezoneReady = true;
    }
  }

  static int idForReminder(String reminderId) {
    return reminderId.hashCode & 0x7fffffff;
  }
}