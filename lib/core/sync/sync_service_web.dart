import 'drive_service_web.dart';
import 'sync_decision.dart';

export 'sync_decision.dart';

/// Web has no filesystem: Google Drive sync is unsupported here.
class SyncService {
  final DriveService drive;

  SyncService({
    required this.drive,
    required Object? dbManager,
    required Object? notesDao,
    required Object? settingsDao,
    required Object? storage,
    required Object? connectivity,
  });

  Future<bool> sync() async => throw const SyncOfflineException();
}
