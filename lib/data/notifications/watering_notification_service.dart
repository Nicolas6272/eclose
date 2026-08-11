import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
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
    // Keep visible in release device logs while iterating on notifications.
    debugPrint('[$_logName] $message');
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

    // permission_handler is more reliable than plugin checkPermissions on iOS.
    final status = await Permission.notification.status;
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return NotificationPermissionStatus.granted;
    }
    if (status.isDenied) return NotificationPermissionStatus.denied;
    if (status.isPermanentlyDenied) return NotificationPermissionStatus.denied;
    return NotificationPermissionStatus.notDetermined;
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
      _log('iOS permission request → $result');
      if (result == true) return true;
      final status = await permissionStatus();
      _log('iOS permission fallback status → $status');
      return status == NotificationPermissionStatus.granted;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final result = await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      _log('Android permission → $result');
      if (result == true) return true;
      final status = await permissionStatus();
      return status == NotificationPermissionStatus.granted;
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
        interruptionLevel: InterruptionLevel.active,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Dev helper: fire the grouped "today" reminder now (+ backup in 3s).
  ///
  /// Returns how many crops were due today (0 = empty-state copy, -1 = no permission).
  Future<int> showTodayReminder(List<UserCrop> crops) async {
    if (!_initialized) await init();
    if (kIsWeb) return 0;

    final allowed = await requestPermission();
    if (!allowed) {
      _log('show today — permission denied');
      return -1;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = _dueOnDay(crops, today);
    final copy = wateringNotificationCopy(due);

    await _plugin.show(
      id: _testNotificationId,
      title: copy.title,
      body: copy.body,
      notificationDetails: _details(),
      payload: 'watering_today',
    );

    _log('showed today reminder — ${due.length} crop(s): ${copy.body}');
    return due.length;
  }
}
