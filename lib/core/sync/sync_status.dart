/// Sync state shown in the UI.
enum SyncStatus { idle, syncing, synced, offline, failed }

class SyncState {
  final SyncStatus status;
  final DateTime? lastSync;
  final String? error;

  const SyncState({required this.status, this.lastSync, this.error});

  const SyncState.idle() : this(status: SyncStatus.idle);
}
