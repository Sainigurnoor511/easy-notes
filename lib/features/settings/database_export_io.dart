import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_manager_io.dart';

const _databaseEntry = 'database.sqlite';
const _manifestEntry = 'manifest.json';
const _attachmentsEntry = 'attachments/';

Future<String> exportDatabase(DatabaseManager manager) async {
  final temp = await getTemporaryDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final database = File(p.join(temp.path, 'backup_database_$stamp.sqlite'));
  await manager.exportTo(database);

  final archive =
      Archive()
        ..addFile(
          ArchiveFile.string(
            _manifestEntry,
            jsonEncode({'format': 'easy-notes-backup', 'version': 1}),
          ),
        )
        ..addFile(
          ArchiveFile.bytes(_databaseEntry, await database.readAsBytes()),
        );

  final docs = await getApplicationDocumentsDirectory();
  final attachmentRoot = Directory(p.join(docs.path, 'attachments'));
  if (await attachmentRoot.exists()) {
    await for (final entity in attachmentRoot.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p
          .relative(entity.path, from: attachmentRoot.path)
          .replaceAll('\\', '/');
      archive.addFile(
        ArchiveFile.bytes(
          '$_attachmentsEntry$relative',
          await entity.readAsBytes(),
        ),
      );
    }
  }

  final destination = File(p.join(temp.path, 'easy_notes_backup_$stamp.zip'));
  await destination.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  await database.delete();
  return destination.path;
}

Future<void> restoreDatabase(DatabaseManager manager, String sourcePath) async {
  final docs = await getApplicationDocumentsDirectory();
  final backupDir = Directory(p.join(docs.path, 'backups'));
  await backupDir.create(recursive: true);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final currentDatabase = File(
    p.join(backupDir.path, 'pre_restore_$stamp.sqlite'),
  );
  await manager.exportTo(currentDatabase);

  final extension = p.extension(sourcePath).toLowerCase();
  if (extension == '.sqlite' || extension == '.db') {
    await manager.replaceWith(File(sourcePath));
    return;
  }

  final source = File(sourcePath);
  const maxCompressedBytes = 512 * 1024 * 1024;
  const maxEntryBytes = 256 * 1024 * 1024;
  const maxExpandedBytes = 2 * 1024 * 1024 * 1024;
  const maxEntries = 10000;
  if (await source.length() > maxCompressedBytes) {
    throw const FormatException('Backup file is too large.');
  }
  final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
  if (archive.length > maxEntries) {
    throw const FormatException('Backup contains too many files.');
  }
  var expandedBytes = 0;
  for (final entry in archive.files) {
    if (entry.size > maxEntryBytes) {
      throw const FormatException('A backup entry is too large.');
    }
    expandedBytes += entry.size;
    if (expandedBytes > maxExpandedBytes) {
      throw const FormatException('Expanded backup is too large.');
    }
  }
  final manifest = archive.findFile(_manifestEntry);
  final databaseEntry = archive.findFile(_databaseEntry);
  if (manifest == null || databaseEntry == null) {
    throw const FormatException('This is not an Easy Notes backup.');
  }
  final manifestData =
      jsonDecode(utf8.decode(manifest.readBytes()!)) as Map<String, dynamic>;
  if (manifestData['format'] != 'easy-notes-backup' ||
      manifestData['version'] != 1) {
    throw const FormatException('Unsupported Easy Notes backup version.');
  }

  final temp = await getTemporaryDirectory();
  final stage = Directory(p.join(temp.path, 'easy_notes_restore_$stamp'));
  if (await stage.exists()) await stage.delete(recursive: true);
  await stage.create(recursive: true);
  final stagedDatabase = File(p.join(stage.path, _databaseEntry));
  await stagedDatabase.writeAsBytes(databaseEntry.readBytes()!, flush: true);
  final stagedAttachments = Directory(p.join(stage.path, 'attachments'));
  await stagedAttachments.create(recursive: true);

  for (final entry in archive.files) {
    if (!entry.isFile || !entry.name.startsWith(_attachmentsEntry)) continue;
    final archivePath = entry.name.substring(_attachmentsEntry.length);
    if (archivePath.contains('\\') || archivePath.contains(':')) {
      throw const FormatException('Backup contains an unsafe file path.');
    }
    final relative = p.posix.normalize(archivePath);
    if (relative.isEmpty ||
        p.posix.isAbsolute(relative) ||
        relative == '..' ||
        relative.startsWith('../')) {
      throw const FormatException('Backup contains an unsafe file path.');
    }
    final destination = File(
      p.normalize(
        p.joinAll([stagedAttachments.path, ...p.posix.split(relative)]),
      ),
    );
    if (!p.isWithin(stagedAttachments.path, destination.path)) {
      throw const FormatException('Backup contains an unsafe file path.');
    }
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(entry.readBytes()!, flush: true);
  }

  final attachmentRoot = Directory(p.join(docs.path, 'attachments'));
  final rollbackAttachments = Directory(
    p.join(docs.path, 'attachments_pre_restore_$stamp'),
  );
  var movedCurrentAttachments = false;
  try {
    if (await attachmentRoot.exists()) {
      await attachmentRoot.rename(rollbackAttachments.path);
      movedCurrentAttachments = true;
    }
    await stagedAttachments.rename(attachmentRoot.path);
    await manager.replaceWith(stagedDatabase);
    await _rebaseAttachmentPaths(manager, attachmentRoot);
    if (movedCurrentAttachments && await rollbackAttachments.exists()) {
      await rollbackAttachments.delete(recursive: true);
    }
  } catch (_) {
    await manager.replaceWith(currentDatabase);
    if (await attachmentRoot.exists()) {
      await attachmentRoot.delete(recursive: true);
    }
    if (movedCurrentAttachments && await rollbackAttachments.exists()) {
      await rollbackAttachments.rename(attachmentRoot.path);
    }
    rethrow;
  } finally {
    if (await stage.exists()) await stage.delete(recursive: true);
  }
}

Future<void> _rebaseAttachmentPaths(
  DatabaseManager manager,
  Directory attachmentRoot,
) async {
  final db = manager.db;
  final attachments = await db.select(db.attachments).get();
  for (final attachment in attachments) {
    final destination = p.join(
      attachmentRoot.path,
      attachment.noteId,
      p.basename(attachment.localPath),
    );
    if (!await File(destination).exists()) {
      throw FormatException('Missing attachment: ${attachment.fileName}');
    }
    await (db.update(db.attachments)..where(
      (row) => row.id.equals(attachment.id),
    )).write(AttachmentsCompanion(localPath: Value(destination)));
  }

  final imageBlocks =
      await (db.select(db.blocks)
        ..where((block) => block.type.equals('image'))).get();
  for (final block in imageBlocks) {
    if (block.content.trim().isEmpty) continue;
    final destination = p.join(
      attachmentRoot.path,
      block.noteId,
      p.basename(block.content),
    );
    if (!await File(destination).exists()) {
      throw const FormatException('Backup is missing a block image.');
    }
    await (db.update(db.blocks)..where(
      (row) => row.id.equals(block.id),
    )).write(BlocksCompanion(content: Value(destination)));
  }
}
