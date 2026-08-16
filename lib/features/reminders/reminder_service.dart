import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local, offline reminders for notes.
class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Note reminders',
      channelDescription: 'Alerts for note reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> scheduleForNote({
    required String noteId,
    required String title,
    required DateTime when,
  }) async {
    await init();
    final now = DateTime.now();
    final scheduled = when.isBefore(now) ? now.add(const Duration(seconds: 1)) : when;
    await _plugin.zonedSchedule(
      _idFor(noteId),
      'Reminder',
      title,
      tz.TZDateTime.from(scheduled, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelForNote(String noteId) async {
    await init();
    await _plugin.cancel(_idFor(noteId));
  }

  static int _idFor(String noteId) => noteId.hashCode & 0x7fffffff;
}