import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/database_manager_io.dart';

/// Exports the live database to `<docs>/exports/easy_notes_backup_<ts>.sqlite`.
/// Returns the destination path.
Future<String> exportDatabase(DatabaseManager manager) async {
  final dir = await getApplicationDocumentsDirectory();
  final exportDir = Directory(p.join(dir.path, 'exports'));
  await exportDir.create(recursive: true);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final dest = File(p.join(exportDir.path, 'easy_notes_backup_$stamp.sqlite'));
  await manager.exportTo(dest);
  return dest.path;
}

/// Restores the database from [sourcePath], backing up the current database
/// first. Returns the new [DatabaseManager] to install into the provider.
Future<void> restoreDatabase(DatabaseManager manager, String sourcePath) async {
  final dir = await getApplicationDocumentsDirectory();
  final backupDir = Directory(p.join(dir.path, 'backups'));
  await backupDir.create(recursive: true);
  final backup = File(p.join(
      backupDir.path, 'pre_restore_${DateTime.now().millisecondsSinceEpoch}.sqlite'));
  await manager.exportTo(backup);
  await manager.replaceWith(File(sourcePath));
}
