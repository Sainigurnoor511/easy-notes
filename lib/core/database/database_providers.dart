import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database_manager.dart';
import 'daos/attachments_dao.dart';
import 'daos/labels_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/settings_dao.dart';

/// Overridden in main() with the fully-initialized manager.
final databaseManagerProvider = StateProvider<DatabaseManager>(
  (ref) => throw StateError('uninitialized'),
);

final databaseProvider = Provider<AppDatabase>(
  (ref) => ref.watch(databaseManagerProvider).db,
);

final notesDaoProvider = Provider<NotesDao>(
  (ref) => NotesDao(ref.watch(databaseProvider)),
);

final labelsDaoProvider = Provider<LabelsDao>(
  (ref) => LabelsDao(ref.watch(databaseProvider)),
);

final attachmentsDaoProvider = Provider<AttachmentsDao>(
  (ref) => AttachmentsDao(ref.watch(databaseProvider)),
);

final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => SettingsDao(ref.watch(databaseProvider)),
);
