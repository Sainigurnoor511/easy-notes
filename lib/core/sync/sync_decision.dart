class SyncOfflineException implements Exception {
  const SyncOfflineException();
}

class SyncFailure implements Exception {
  final String message;
  const SyncFailure(this.message);
}

/// Direction decided by last-write-wins at the database-file level.
///
/// Simple, documented strategy:
///  - local max `updated_at`  > remote max `updated_at` -> upload local
///  - remote max `updated_at` > local max `updated_at`  -> download remote
///  - timestamps equal                                   -> keep local
enum SyncDirection { none, upload, download }

/// Pure decision helper, unit-tested.
SyncDirection decideSyncDirection({
  required int localRevision,
  required DateTime? localMaxUpdatedAt,
  required int? remoteRevision,
  required DateTime? remoteMaxUpdatedAt,
}) {
  // Brand new device: pull whatever exists remotely.
  if (localRevision == 0 && remoteRevision != null) {
    return SyncDirection.download;
  }
  // Nothing remote yet: push.
  if (remoteRevision == null) return SyncDirection.upload;

  final local = localMaxUpdatedAt;
  final remote = remoteMaxUpdatedAt;
  if (local == null) return SyncDirection.upload;
  if (remote == null || local.isAfter(remote)) return SyncDirection.upload;
  if (remote.isAfter(local)) return SyncDirection.download;
  return SyncDirection.none;
}
