import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/models/auth_user.dart';
import 'database/database_providers.dart';
import 'storage/attachment_storage.dart';
import 'sync/drive_service.dart';
import 'sync/google_auth.dart';
import 'sync/sync_service.dart';
import 'sync/sync_status.dart';

final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

final attachmentStorageProvider = Provider<AttachmentStorage>(
  (ref) => AttachmentStorage(),
);

final driveServiceProvider = Provider<DriveService>(
  (ref) => DriveService(googleSignInInstance),
);

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    drive: ref.watch(driveServiceProvider),
    dbManager: ref.watch(databaseManagerProvider),
    notesDao: ref.watch(notesDaoProvider),
    settingsDao: ref.watch(settingsDaoProvider),
    storage: ref.watch(attachmentStorageProvider),
    connectivity: Connectivity(),
  );
});

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() => _restore();

  Future<AuthState> _restore() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final saved = prefs.getString('auth_user');
    final user = saved == null ? null : AuthUser.fromPrefs(_decodePrefs(saved));

    if (googleSignInInstance.currentUser != null) {
      return AuthState(status: AuthStatus.signedIn, user: _fromGoogle());
    }
    try {
      final account = await googleSignInInstance.signInSilently();
      if (account != null) {
        return AuthState(status: AuthStatus.signedIn, user: _fromGoogle());
      }
    } catch (_) {
      // Google temporarily unavailable: fall through to offline mode.
    }
    if (user != null) {
      return AuthState(status: AuthStatus.offline, user: user);
    }
    return const AuthState.signedOut();
  }

  AuthUser _fromGoogle() {
    final acc = googleSignInInstance.currentUser;
    return AuthUser(
      name: acc?.displayName ?? 'Google User',
      email: acc?.email ?? '',
      photoUrl: acc?.photoUrl,
    );
  }

  Map<String, String> _decodePrefs(String raw) {
    final map = <String, String>{};
    for (final pair in raw.split(';')) {
      final parts = pair.split('=');
      if (parts.length == 2) map[parts[0]] = parts[1];
    }
    return map;
  }

  Future<void> signIn() async {
    try {
      final acc = await googleSignInInstance.signIn();
      if (acc == null) return; // user cancelled
      final user = _fromGoogle();
      final prefs = await ref.read(sharedPrefsProvider.future);
      await prefs.setString(
        'auth_user',
        'name=${user.name};email=${user.email};photoUrl=${user.photoUrl ?? ''}',
      );
      state = AsyncData(AuthState(status: AuthStatus.signedIn, user: user));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> signOut() async {
    await googleSignInInstance.signOut();
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.remove('auth_user');
    state = const AsyncData(AuthState.signedOut());
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

class ThemeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final v = prefs.getString('theme_mode');
    return ThemeMode.values.firstWhere(
      (m) => m.name == v,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = AsyncData(mode);
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString('theme_mode', mode.name);
  }
}

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

// ---------------------------------------------------------------------------
// Sync
// ---------------------------------------------------------------------------

class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState.idle();

  Future<void> syncNow() async {
    if (state.status == SyncStatus.syncing) return;
    state = SyncState(status: SyncStatus.syncing, lastSync: state.lastSync);
    try {
      final replaced = await ref.read(syncServiceProvider).sync();
      if (replaced) {
        // A remote download replaced the live database: bump provider state
        // so DAOs and watchers rebuild against the new connection.
        final manager = ref.read(databaseManagerProvider);
        ref.read(databaseManagerProvider.notifier).state = manager;
      }
      state = SyncState(status: SyncStatus.synced, lastSync: DateTime.now());
    } on SyncOfflineException {
      state = SyncState(status: SyncStatus.offline, lastSync: state.lastSync);
    } catch (e) {
      state = SyncState(
        status: SyncStatus.failed,
        lastSync: state.lastSync,
        error: e.toString(),
      );
    }
  }

  Future<void> syncOnResume() async {
    final auth = ref.read(authControllerProvider).valueOrNull;
    if (auth?.status == AuthStatus.signedIn) {
      await syncNow();
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

// ---------------------------------------------------------------------------
// Connectivity -> auto sync when back online
// ---------------------------------------------------------------------------

final connectivityStreamProvider = StreamProvider<ConnectivityResult>((ref) {
  final stream = Connectivity().onConnectivityChanged;
  return stream.map(
    (results) =>
        results.contains(ConnectivityResult.none)
            ? ConnectivityResult.none
            : results.isNotEmpty
            ? results.first
            : ConnectivityResult.none,
  );
});
