import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../crop_catalog.dart';
import '../models/user_crop.dart';
import 'watering_notification_copy.dart';

enum NotificationPermissionStatus {
  granted,
  denied,
  notDetermined,
  unsupported,
}

/// Schedules a single grouped morning reminder (08:00 local) for each day
/// in the horizon where at least one crop is due / overdue.
class WateringNotificationService {
  WateringNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    this.morningHour = 8,
    this.horizonDays = 14,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _logName = 'WateringNotifs';
  static const _channelId = 'watering_reminders';
  static const _channelName = 'Rappels d\'arrosage';
  static const _channelDescription =
      'Rappel matinal regroupé quand des cultures sont à arroser';
  static const _idBase = 4200;
  static const _testNotificationId = 4199;

  final FlutterLocalNotificationsPlugin _plugin;
  final int morningHour;
  final int horizonDays;

  bool _initialized = false;

  void _log(String message) {
    developer.log(message, name: _logName);
    if (kDebugMode) {
      debugPrint('[$_logName] $message');
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    await _configureLocalTimeZone();

    const androidInit = AndroidInitializationSettings('ic_notification');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(settings: settings);
    await _ensureAndroidChannel();
    _initialized = true;
    _log('initialized (tz=${tz.local.name}, morning=$morningHour:00)');
  }

  Future<void> _configureLocalTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error) {
      // Simulator / desktop fallback: keep UTC if lookup fails.
      _log('timezone lookup failed ($error) — falling back to UTC');
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _ensureAndroidChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<NotificationPermissionStatus> permissionStatus() async {
    if (kIsWeb) return NotificationPermissionStatus.unsupported;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final options = await ios?.checkPermissions();
      if (options == null) return NotificationPermissionStatus.notDetermined;
      final granted = (options.isEnabled == true) ||
          (options.isAlertEnabled == true) ||
          (options.isBadgeEnabled == true) ||
          (options.isSoundEnabled == true);
      if (granted) return NotificationPermissionStatus.granted;
      // iOS does not expose "not determined" distinctly here after a prompt.
      return NotificationPermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled();
      if (enabled == true) return NotificationPermissionStatus.granted;
      if (enabled == false) return NotificationPermissionStatus.denied;
      return NotificationPermissionStatus.notDetermined;
    }

    return NotificationPermissionStatus.unsupported;
  }

  /// Requests OS permission. Returns whether notifications are usable after.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final result = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _log('iOS permission → $result');
      return result == true;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final result = await android?.requestNotificationsPermission();
      // Best-effort exact alarms for morning precision.
      await android?.requestExactAlarmsPermission();
      _log('Android permission → $result');
      return result != false;
    }

    return false;
  }

  Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
    _log('cancelled all');
  }

  /// Recompute and schedule morning reminders from current crop state.
  Future<void> reschedule(List<UserCrop> crops) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    final status = await permissionStatus();
    if (status != NotificationPermissionStatus.granted) {
      await _cancelHorizon();
      _log('skip schedule — permission=$status');
      return;
    }

    await _cancelHorizon();

    if (crops.isEmpty) {
      _log('skip schedule — no crops');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = 0;

    for (var offset = 0; offset < horizonDays; offset++) {
      final day = DateTime(now.year, now.month, now.day)
          .add(Duration(days: offset));
      final fireAt = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        morningHour,
      );
      if (!fireAt.isAfter(now)) continue;

      final due = _dueOnDay(crops, day);
      if (due.isEmpty) continue;

      final copy = wateringNotificationCopy(due);
      final id = _idBase + offset;

      await _plugin.zonedSchedule(
        id: id,
        title: copy.title,
        body: copy.body,
        scheduledDate: fireAt,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'watering',
      );
      scheduled++;
      _log(
        'scheduled #$id at $fireAt — ${due.length} crop(s): ${copy.body}',
      );
    }

    _log('reschedule done — $scheduled notification(s)');
  }

  Future<void> _cancelHorizon() async {
    for (var offset = 0; offset < horizonDays; offset++) {
      await _plugin.cancel(id: _idBase + offset);
    }
    await _plugin.cancel(id: _testNotificationId);
  }

  List<UserCrop> _dueOnDay(List<UserCrop> crops, DateTime day) {
    final due = <UserCrop>[];
    for (final crop in crops) {
      final catalog = CropCatalog.byId(crop.catalogCropId);
      if (catalog == null) continue;
      if (crop.isDue(catalog, now: day)) {
        due.add(crop);
      }
    }
    return due;
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Debug helper: fire a sample reminder in [seconds].
  Future<void> scheduleTestIn({int seconds = 5}) async {
    if (!_initialized) await init();
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    await _plugin.zonedSchedule(
      id: _testNotificationId,
      title: 'Arrosage (test)',
      body: 'Notification de test Éclose',
      scheduledDate: when,
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'watering_test',
    );
    _log('test notification scheduled for $when');
  }
}
