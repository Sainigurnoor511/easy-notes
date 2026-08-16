import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/database_manager.dart';
import 'core/database/database_providers.dart';
import 'features/reminders/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final manager = await DatabaseManager.open();
  await ReminderService.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseManagerProvider.overrideWith((ref) => manager),
      ],
      child: const EasyNotesApp(),
    ),
  );
}