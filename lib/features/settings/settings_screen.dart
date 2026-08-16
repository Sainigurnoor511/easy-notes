import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/database_providers.dart';
import '../../core/sync/sync_status.dart';
import '../../shared/models/auth_user.dart';
import 'database_export_io.dart' if (dart.library.js_interop) 'database_export_web.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to connect to Google.')));
      }
    });

    final authAsync = ref.watch(authControllerProvider);
    final auth = authAsync.valueOrNull;
    final sync = ref.watch(syncControllerProvider);
    final signedIn = auth?.status == AuthStatus.signedIn ||
        auth?.status == AuthStatus.offline;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            _section('Appearance', [
              Consumer(builder: (context, ref, _) {
                final mode = ref.watch(themeControllerProvider).valueOrNull ??
                    ThemeMode.system;
                return ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Theme'),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(
                          value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment(
                          value: ThemeMode.system, label: Text('System')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => ref
                        .read(themeControllerProvider.notifier)
                        .set(s.first),
                  ),
                );
              }),
            ]),
            if (!kIsWeb)
              _section('Sync & Backup', [
                if (signedIn) ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: auth!.user!.photoUrl != null &&
                              auth.user!.photoUrl!.isNotEmpty
                          ? NetworkImage(auth.user!.photoUrl!)
                          : null,
                      child: auth.user!.photoUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(auth.user!.name),
                    subtitle: Text(auth.user!.email),
                  ),
                  if (auth.status == AuthStatus.offline)
                    const ListTile(
                      leading: Icon(Icons.cloud_off),
                      title: Text('Offline'),
                      subtitle:
                          Text('Will sync when Google is reachable again.'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('Last sync'),
                    subtitle: Text(sync.lastSync == null
                        ? 'Never'
                        : DateFormat('d MMM y, h:mm a').format(sync.lastSync!)),
                    trailing: _syncIcon(sync.status),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Sync Now'),
                    onTap: () =>
                        ref.read(syncControllerProvider.notifier).syncNow(),
                  ),
                  if (sync.status == SyncStatus.failed)
                    ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: const Text('Sync failed'),
                      subtitle: const Text(
                          'Your local notes are safe. We will retry when you are online.'),
                      trailing: FilledButton(
                        onPressed: () => ref
                            .read(syncControllerProvider.notifier)
                            .syncNow(),
                        child: const Text('Retry'),
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Disconnect'),
                    onTap: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: const Text('Not connected'),
                    subtitle: const Text(
                        'Your notes stay on this device. Connect Google Drive to back up and sync across devices.'),
                  ),
                  ListTile(
                    leading: authAsync.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    title: const Text('Connect Google Drive'),
                    onTap: authAsync.isLoading
                        ? null
                        : () =>
                            ref.read(authControllerProvider.notifier).signIn(),
                  ),
                ],
              ]),
            _section('Storage', [
              _StorageTile(ref: ref, context: context),
            ]),
            _section('About', [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('App version'),
                subtitle: Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open Source Licenses'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Easy Notes',
                  applicationVersion: '1.0.0',
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _syncIcon(SyncStatus status) {
    final icon = switch (status) {
      SyncStatus.syncing => Icons.sync,
      SyncStatus.synced => Icons.cloud_done_outlined,
      SyncStatus.offline => Icons.cloud_off_outlined,
      SyncStatus.failed => Icons.error_outline,
      SyncStatus.idle => Icons.cloud_outlined,
    };
    return Icon(icon);
  }
}

class _StorageTile extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final BuildContext context;

  const _StorageTile({required this.ref, required this.context});

  @override
  ConsumerState<_StorageTile> createState() => _StorageTileState();
}

class _StorageTileState extends ConsumerState<_StorageTile> {
  int? _dbSize;
  int? _attSize;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final manager = ref.read(databaseManagerProvider);
    final dbSize = await manager.dbSize();
    final attSize = kIsWeb ? 0 : await ref.read(attachmentStorageProvider).totalSize();
    if (mounted) {
      setState(() {
        _dbSize = dbSize;
        _attSize = attSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: const Text('Database size'),
          subtitle: Text(_fmt(_dbSize)),
        ),
        if (!kIsWeb)
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Attachment size'),
            subtitle: Text(_fmt(_attSize)),
          ),
        if (!kIsWeb) ...[
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Database'),
            subtitle: const Text('Copies the SQLite database to local storage'),
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Restore Database'),
            subtitle: const Text('Replace local data with a backup file'),
            onTap: _restore,
          ),
        ],
      ],
    );
  }

  String _fmt(int? bytes) {
    if (bytes == null) return '...';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _export() async {
    try {
      final manager = ref.read(databaseManagerProvider);
      final path = await exportDatabase(manager);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Database exported to $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db'],
    );
    if (result == null || result.files.isEmpty) return;
    final sourcePath = result.files.first.path!;
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined),
        title: const Text('Restore database?'),
        content: const Text(
            'Restoring will replace your current local data. '
            'A backup of the current database will be saved first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final manager = ref.read(databaseManagerProvider);
      await restoreDatabase(manager, sourcePath);
      ref.read(databaseManagerProvider.notifier).state = manager;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restored.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }
}

Widget _section(String title, List<Widget> children) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.sm, Spacing.md, Spacing.sm, Spacing.xs),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      Card(child: Column(children: children)),
    ],
  );
}
