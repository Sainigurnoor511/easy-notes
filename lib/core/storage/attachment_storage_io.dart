import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages local attachment files.
///
/// Files live under `<appDocs>/attachments/<noteId>/<attachmentId>_<name>`.
/// SQLite stores only metadata. Missing files must never crash the UI.
class AttachmentStorage {
  Future<Directory> _attachmentsRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> noteDir(String noteId) async {
    final root = await _attachmentsRoot();
    final dir = Directory(p.join(root.path, noteId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> save(
      {required String noteId, required String sourcePath, required String fileName}) async {
    final dir = await noteDir(noteId);
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dest = File(p.join(dir.path, safeName));
    if (await dest.exists()) {
      await dest.delete();
    }
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  Future<void> deleteFile(String localPath) async {
    try {
      final f = File(localPath);
      if (await f.exists()) {
        await f.delete();
      }
    } on FileSystemException {
      // Missing attachment: ignore.
    }
  }

  Future<void> deleteNoteFiles(String noteId) async {
    try {
      final root = await _attachmentsRoot();
      final dir = Directory(p.join(root.path, noteId));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on FileSystemException {
      // Ignore.
    }
  }

  Future<int> totalSize() async {
    var size = 0;
    final root = await _attachmentsRoot();
    if (!await root.exists()) return 0;
    await for (final f in root.list(recursive: true)) {
      if (f is File) {
        try {
          size += await f.length();
        } catch (_) {}
      }
    }
    return size;
  }

  /// Relative key (`noteId__fileName`) -> file, for Drive sync.
  Future<Map<String, File>> listAllFiles() async {
    final root = await _attachmentsRoot();
    final map = <String, File>{};
    if (!await root.exists()) return map;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) {
        final relative =
            entity.absolute.path.substring(root.absolute.path.length + 1);
        final parts = relative.split(RegExp(r'[\\/]'));
        if (parts.length != 2) continue;
        map['${parts[0]}__${parts[1]}'] = entity;
      }
    }
    return map;
  }

  Future<String?> exportDatabaseFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'easy_notes.sqlite');
  }
}
