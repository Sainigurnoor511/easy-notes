import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local, offline reminders for notes.
///
/// Reminders are **exact** alarms. An inexact alarm is the default advice for
/// battery reasons, but One UI defers those by minutes to hours and coalesces
/// them with other wakeups, which for a reminder means it effectively never
/// arrives when asked. [_scheduleMode] falls back to inexact only when the user
/// has actually revoked the exact-alarm permission.
class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Set by the app so tapping a reminder opens its note. Held as a callback
  /// rather than a router reference because notifications are delivered from a
  /// plugin callback that has no `BuildContext`.
  static void Function(String noteId)? onOpenNote;
  static Future<void> Function(String noteId, String actionId)?
  onReminderAction;

  /// The note a cold launch came from, when the app was started by tapping a
  /// reminder. Consumed once by the app shell.
  static String? pendingNoteId;
  static String? pendingActionId;

  static const String actionOpen = 'open';
  static const String actionComplete = 'complete';
  static const String actionReschedule = 'reschedule';

  static const String _channelId = 'reminders.v2';

  /// A channel's importance and sound are frozen when Android first creates it,
  /// and later edits to the same id are ignored for the life of the install. The
  /// original `reminders` channel was created without an explicit sound, so it
  /// needs a new id rather than a change in place.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _channelId,
    'Note reminders',
    description: 'Alerts for note reminders',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final noteId = response.payload;
        if (noteId == null || noteId.isEmpty) return;
        final actionId =
            response.actionId == null || response.actionId!.isEmpty
                ? actionOpen
                : response.actionId!;
        final action = onReminderAction;
        if (action != null) {
          action(noteId, actionId);
          return;
        }
        if (actionId == actionOpen) {
          final open = onOpenNote;
          if (open != null) {
            open(noteId);
            return;
          }
        }
        pendingNoteId = noteId;
        pendingActionId = actionId;
      },
    );

    // Created up front, so the channel exists with the right importance before
    // the first notification rather than being inferred from it.
    await _android?.createNotificationChannel(_channel);

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final payload = launch?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        pendingNoteId = payload;
        final launchAction = launch?.notificationResponse?.actionId;
        pendingActionId =
            launchAction == null || launchAction.isEmpty
                ? actionOpen
                : launchAction;
      }
    }

    _initialized = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  /// Asks for everything a reminder needs, once, at a point where the user has
  /// context for the prompt.
  ///
  /// `POST_NOTIFICATIONS` is required from Android 13; without the grant every
  /// notification is dropped silently. `SCHEDULE_EXACT_ALARM` is user-revocable
  /// from Android 12 and opens a system settings page, so it is only requested
  /// when the system says it is not already held.
  static Future<void> requestPermissions() async {
    await init();
    final android = _android;
    if (android == null) return;
    await android.requestNotificationsPermission();
    final canBeExact = await android.canScheduleExactNotifications() ?? false;
    if (!canBeExact) await android.requestExactAlarmsPermission();
  }

  static Future<AndroidScheduleMode> _scheduleMode() async {
    final canBeExact = await _android?.canScheduleExactNotifications() ?? false;
    return canBeExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      // Tells the system this is time-critical, which keeps it out of
      // notification grouping and summarisation.
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      actions: const [
        AndroidNotificationAction(
          actionOpen,
          'Open note',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          actionComplete,
          'Mark completed',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          actionReschedule,
          'Reschedule',
          showsUserInterface: true,
        ),
      ],
    ),
  );

  static Future<void> scheduleForNote({
    required String noteId,
    required String title,
    required DateTime when,
  }) async {
    await init();
    final now = DateTime.now();
    final scheduled =
        when.isBefore(now) ? now.add(const Duration(seconds: 1)) : when;

    await _plugin.zonedSchedule(
      _idFor(noteId),
      'Reminder',
      title.trim().isEmpty ? 'Untitled note' : title.trim(),
      // Built from an absolute instant, so the zone only has to be *a* valid
      // zone — converting a local DateTime to UTC preserves the epoch moment.
      // Deliberately not `tz.local`, which stays UTC unless the device zone is
      // looked up and set, and so only reads as correct by accident.
      tz.TZDateTime.from(scheduled.toUtc(), tz.UTC),
      _details,
      androidScheduleMode: await _scheduleMode(),
      payload: noteId,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelForNote(String noteId) async {
    await init();
    await _plugin.cancel(_idFor(noteId));
  }

  /// Rebuilds every pending alarm from the notes that own them.
  ///
  /// The system drops scheduled alarms on reboot, force-stop and app update. The
  /// boot receiver covers a reboot, but nothing covers the other two, so the
  /// database is treated as the source of truth on every start: whatever is in
  /// `reminderAt` is what should be armed.
  static Future<void> rescheduleAll(
    Iterable<({String noteId, String title, DateTime when})> reminders,
  ) async {
    await init();
    final now = DateTime.now();
    for (final reminder in reminders) {
      // Past reminders are not re-fired: the user has already seen them, or
      // missed them while the device was off, and firing on every launch would
      // turn one missed alert into a permanent one.
      if (reminder.when.isBefore(now)) continue;
      await scheduleForNote(
        noteId: reminder.noteId,
        title: reminder.title,
        when: reminder.when,
      );
    }
  }

  /// Notification ids are ints, note ids are uuids, so the id has to be derived.
  ///
  /// FNV-1a rather than [String.hashCode]: Dart's string hash is not stable
  /// across runs or SDK versions, so a cancel issued after an upgrade could
  /// compute a different id than the schedule did and leave the alarm armed.
  static int _idFor(String noteId) {
    var hash = 0x811c9dc5;
    for (final unit in noteId.codeUnits) {
      hash = (hash ^ unit) * 0x01000193;
      hash &= 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
