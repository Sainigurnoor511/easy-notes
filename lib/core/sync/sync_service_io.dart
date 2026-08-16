import 'dart:async';
import 'dart:io' as io;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/daos/notes_dao.dart';
import '../database/daos/settings_dao.dart';
import '../database/database_manager_io.dart';
import '../storage/attachment_storage_io.dart';
import 'drive_service_io.dart';
import 'sync_decision.dart';

export 'sync_decision.dart';

const String _dbFileName = 'database.sqlite';
const String _metaFileName = 'metadata.json';
const String _attachmentsFolderName = 'attachments';
const String _folderName = 'MyNotes';

class SyncService {
  final DriveService drive;
  final DatabaseManager dbManager;
  final NotesDao notesDao;
  final SettingsDao settingsDao;
  final AttachmentStorage storage;
  final Connectivity connectivity;

  SyncService({
    required this.drive,
    required this.dbManager,
    required this.notesDao,
    required this.settingsDao,
    required this.storage,
    required this.connectivity,
  });

  /// Runs one sync pass. Returns true when the local database was replaced
  /// by a remote download. Throws [SyncOfflineException] when offline and
  /// [SyncFailure] on other errors. Never deletes local data.
  Future<bool> sync() async {
    if (!drive.hasSession) throw const SyncOfflineException();
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult.every((r) => r == ConnectivityResult.none)) {
      throw const SyncOfflineException();
    }

    var replaced = false;
    try {
      final folderId = await drive.ensureFolder(_folderName);

      final localMax = await _localMaxUpdatedAt();
      final localRev = await settingsDao.lastRevision() ?? 0;
      final remoteMeta = await drive.readMetadata(
          folderId: folderId, fileName: _metaFileName);
      final remoteRev = remoteMeta?['revision'] as int?;
      final remoteMax = remoteMeta?['maxUpdatedAt'] == null
          ? null
          : DateTime.tryParse(remoteMeta!['maxUpdatedAt'] as String);

      final direction = decideSyncDirection(
        localRevision: localRev,
        localMaxUpdatedAt: localMax,
        remoteRevision: remoteRev,
        remoteMaxUpdatedAt: remoteMax,
      );

      switch (direction) {
        case SyncDirection.none:
          break;
        case SyncDirection.upload:
          await _upload(folderId, localMax, localRev, remoteRev);
        case SyncDirection.download:
          await _download(folderId, localRev, remoteRev!);
          replaced = true;
      }

      await settingsDao.setLastSync(DateTime.now());
    } on SyncOfflineException {
      rethrow;
    } on SyncFailure {
      rethrow;
    } catch (e) {
      throw SyncFailure(e.toString());
    }
    return replaced;
  }

  Future<DateTime?> _localMaxUpdatedAt() async {
    return notesDao.maxUpdatedAt();
  }

  Future<void> _upload(
    String folderId,
    DateTime? localMax,
    int localRev,
    int? remoteRev,
  ) async {
    // DB file
    final temp = await _tempFile('upload.sqlite');
    await dbManager.exportTo(temp);
    await drive.uploadFile(
      file: temp,
      name: _dbFileName,
      parentId: folderId,
      mimeType: 'application/octet-stream',
    );

    // Attachments
    final attachmentsFolder =
        await drive.ensureFolderIn(_attachmentsFolderName, folderId);
    final files = await storage.listAllFiles();
    for (final entry in files.entries) {
      await drive.uploadFile(
        file: entry.value,
        name: entry.key,
        parentId: attachmentsFolder,
        mimeType: 'application/octet-stream',
      );
    }

    // Metadata (increment revision beyond both sides)
    final nextRev = (localRev > (remoteRev ?? 0) ? localRev : (remoteRev ?? 0)) + 1;
    await drive.writeMetadata(
      folderId: folderId,
      fileName: _metaFileName,
      data: {
        'revision': nextRev,
        'maxUpdatedAt': (localMax ?? DateTime.now()).toIso8601String(),
        'lastSyncAt': DateTime.now().toIso8601String(),
      },
    );
    await settingsDao.setRevision(nextRev);
    await temp.delete();
  }

  Future<void> _download(String folderId, int localRev, int remoteRev) async {
    final tempDir = await getTemporaryDirectory();
    final dbId = await drive.findFileId(parent: folderId, name: _dbFileName);
    if (dbId == null) throw const SyncFailure('Remote database missing');
    final tempDb = io.File(p.join(tempDir.path, 'download.sqlite'));
    await drive.downloadFile(fileId: dbId, dest: tempDb);

    // Pull attachments before swapping the DB so new rows resolve to files.
    final attachmentsFolder =
        await drive.ensureFolderIn(_attachmentsFolderName, folderId);
    final remoteFiles = await drive.listFilesInFolder(attachmentsFolder);
    for (final entry in remoteFiles.entries) {
      final relative = entry.key;
      if (!relative.contains('__')) continue;
      final noteId = relative.split('__').first;
      final fileName = relative.split('__').sublist(1).join('__');
      final dest = io.File(
          p.join((await storage.noteDir(noteId)).path, fileName));
      await drive.downloadFile(fileId: entry.value, dest: dest);
    }

    await dbManager.replaceWith(tempDb);
    await settingsDao.setRevision(remoteRev);
  }

  Future<io.File> _tempFile(String name) async {
    final dir = await getTemporaryDirectory();
    return io.File(p.join(dir.path, name));
  }
}