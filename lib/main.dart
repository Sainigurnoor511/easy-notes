import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/daos/notes_dao.dart';
import 'core/database/database_manager.dart';
import 'core/database/database_providers.dart';
import 'features/reminders/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final manager = await DatabaseManager.open();
  await ReminderService.init();

  // Android drops pending alarms on reboot, force-stop and app update. The boot
  // receiver covers the reboot; nothing covers the other two, so the database is
  // treated as the source of truth on every start and the alarms are re-armed
  // from it. Not awaited: it is a background repair, and blocking the first
  // frame on it would cost startup time for no visible gain.
  final notesDao = NotesDao(manager.db);
  notesDao.getReminders().then((notes) {
    ReminderService.rescheduleAll(
      notes
          .where((n) => n.reminderAt != null)
          .map((n) => (noteId: n.id, title: n.title, when: n.reminderAt!)),
    );
  });

  runApp(
    ProviderScope(
      overrides: [databaseManagerProvider.overrideWith((ref) => manager)],
      child: const EasyNotesApp(),
    ),
  );
}
