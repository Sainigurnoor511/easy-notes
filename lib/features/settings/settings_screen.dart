import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/database_providers.dart';
import '../../core/sync/sync_status.dart';
import '../../shared/models/auth_user.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/note_dialogs.dart';
import 'database_export_io.dart'
    if (dart.library.js_interop) 'database_export_web.dart';

/// Settings.
///
/// Four sections, each stating a thing once: the account (and its sync state),
/// appearance, storage, and about. Connection state deliberately lives in one
/// place here — the top bar's sync button covers it everywhere else.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final gutter = wide ? Spacing.xxl : Spacing.gutter;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, Spacing.xl, gutter, Spacing.xxxl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.form),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Settings', style: context.texts.headlineLarge),
                const SizedBox(height: Spacing.xl),
                const _AccountSection(),
                const SizedBox(height: Spacing.lg),
                const _AppearanceSection(),
                const SizedBox(height: Spacing.lg),
                const _StorageSection(),
                const SizedBox(height: Spacing.lg),
                const _AboutSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Account and its sync state, in one place.
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authControllerProvider);
    final auth = authAsync.valueOrNull;
    final user = auth?.user;
    final sync = ref.watch(syncControllerProvider);
    final connected = auth?.status == AuthStatus.signedIn ||
        auth?.status == AuthStatus.offline;

    return SettingsSection(
      icon: Symbols.account_circle,
      title: 'Account',
      description: connected
          ? null
          : 'Notes are saved on this device. Connect Drive to back them up.',
      children: [
        if (!connected || user == null)
          SettingsRow(
            leading: Symbols.cloud_off,
            title: 'Not connected',
            trailing: FilledButton.icon(
              onPressed: authAsync.isLoading
                  ? null
                  : () => ref.read(authControllerProvider.notifier).signIn(),
              icon: authAsync.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.login, size: 18),
              label: const Text('Connect Drive'),
            ),
          )
        else ...[
          _ConnectedAccount(user: user, offline: auth!.status == AuthStatus.offline),
          const SizedBox(height: Spacing.md),
          SettingsRow(
            leading: Symbols.history,
            title: 'Last synced',
            description: sync.lastSync == null
                ? 'Not synced yet'
                : DateFormat('d MMM, HH:mm').format(sync.lastSync!),
            trailing: OutlinedButton.icon(
              onPressed: sync.status == SyncStatus.syncing
                  ? null
                  : () => ref.read(syncControllerProvider.notifier).syncNow(),
              icon: const Icon(Symbols.sync, size: 17),
              label: Text(
                  sync.status == SyncStatus.syncing ? 'Syncing…' : 'Sync now'),
            ),
          ),
        ],
        // Sign-in needs an OAuth client registered for this app's package and
        // signing key. Without it the failure is permanent, so it's explained
        // here rather than in a snackbar that disappears.
        if (authAsync.hasError && !authAsync.isLoading) ...[
          const SizedBox(height: Spacing.md),
          _ErrorNote(
            title: "Couldn't connect to Google",
            body: 'Drive sync needs a Google Cloud OAuth client registered for '
                'this app. Until that is set up, notes stay on this device — '
                'nothing is lost.',
          ),
        ],
        if (sync.status == SyncStatus.failed && sync.error != null) ...[
          const SizedBox(height: Spacing.md),
          _ErrorNote(title: 'Last sync failed', body: sync.error!),
        ],
      ],
    );
  }
}

class _ConnectedAccount extends ConsumerWidget {
  final AuthUser user;
  final bool offline;

  const _ConnectedAccount({required this.user, required this.offline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final photoUrl = user.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return SettingsRow(
      title: user.name.trim().isEmpty ? 'Google account' : user.name,
      description: user.email.isNotEmpty
          ? user.email
          : (offline ? 'Will reconnect when Google is reachable' : null),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPhoto)
            CircleAvatar(radius: 16, backgroundImage: NetworkImage(photoUrl))
          else
            CircleAvatar(
              radius: 16,
              backgroundColor: palette.primaryWash,
              child: Icon(Symbols.person, size: 18, color: palette.onPrimaryWash),
            ),
          const SizedBox(width: Spacing.sm),
          GhostIconButton(
            icon: Symbols.logout,
            tooltip: 'Disconnect',
            color: palette.textTertiary,
            iconSize: 18,
            onPressed: () async {
              final ok = await showDangerConfirmDialog(
                context,
                title: 'Disconnect Drive?',
                message: 'Your notes stay on this device. They stop syncing '
                    'until you connect again.',
                confirmLabel: 'Disconnect',
              );
              if (ok) {
                await ref.read(authControllerProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// A persistent explanation of a failure, on the error wash.
class _ErrorNote extends StatelessWidget {
  final String title;
  final String body;

  const _ErrorNote({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.errorWash,
        borderRadius: AppRadii.all(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.error, size: 18, color: palette.onErrorWash),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.texts.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: palette.onErrorWash,
                  ),
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  body,
                  style: context.texts.bodySmall
                      ?.copyWith(color: palette.onErrorWash),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme mode as three preview cards.
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(themeControllerProvider).valueOrNull ?? ThemeMode.system;

    final cards = [
      _ThemeCard(
        mode: ThemeMode.light,
        label: 'Light',
        selected: mode == ThemeMode.light,
        onTap: () =>
            ref.read(themeControllerProvider.notifier).set(ThemeMode.light),
      ),
      _ThemeCard(
        mode: ThemeMode.dark,
        label: 'Dark',
        selected: mode == ThemeMode.dark,
        onTap: () =>
            ref.read(themeControllerProvider.notifier).set(ThemeMode.dark),
      ),
      _ThemeCard(
        mode: ThemeMode.system,
        label: 'System',
        selected: mode == ThemeMode.system,
        onTap: () =>
            ref.read(themeControllerProvider.notifier).set(ThemeMode.system),
      ),
    ];

    return SettingsSection(
      icon: Symbols.palette,
      title: 'Appearance',
      children: [
        Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: Spacing.md),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      ],
    );
  }
}

/// A theme option with a miniature of the canvas it produces.
class _ThemeCard extends StatelessWidget {
  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      borderRadius: AppRadii.all(AppRadii.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: AppRadii.all(AppRadii.md),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _preview(),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(
                  selected
                      ? Symbols.radio_button_checked
                      : Symbols.radio_button_unchecked,
                  size: 17,
                  fill: selected ? 1 : 0,
                  color: selected ? palette.primary : palette.textTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    const light = AppPalette.light;
    const dark = AppPalette.dark;

    if (mode == ThemeMode.system) {
      return SizedBox(
        height: 48,
        child: ClipRRect(
          borderRadius: AppRadii.all(AppRadii.base),
          child: Row(
            children: [
              Expanded(child: _half(light)),
              Expanded(child: _half(dark)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: ClipRRect(
        borderRadius: AppRadii.all(AppRadii.base),
        child: _half(mode == ThemeMode.dark ? dark : light),
      ),
    );
  }

  Widget _half(AppPalette p) => Container(
        color: p.canvas,
        padding: const EdgeInsets.all(Spacing.sm - 2),
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(p, 0.45),
            const SizedBox(height: 4),
            _bar(p, 0.9),
            const SizedBox(height: 4),
            _bar(p, 0.7),
          ],
        ),
      );

  Widget _bar(AppPalette p, double widthFactor) => FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 5,
          decoration: BoxDecoration(
            color: p.surfaceHover,
            borderRadius: AppRadii.all(AppRadii.handle),
          ),
        ),
      );
}

/// What the app is actually using on disk, plus backup.
class _StorageSection extends ConsumerStatefulWidget {
  const _StorageSection();

  @override
  ConsumerState<_StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<_StorageSection> {
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
    final attSize =
        kIsWeb ? 0 : await ref.read(attachmentStorageProvider).totalSize();
    if (mounted) {
      setState(() {
        _dbSize = dbSize;
        _attSize = attSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SettingsSection(
      icon: Symbols.storage,
      title: 'Storage',
      children: [
        SettingsRow(
          leading: Symbols.description,
          title: 'Notes',
          trailing: Text(
            _fmt(_dbSize),
            style: context.mono.copyWith(
              fontWeight: FontWeight.w500,
              color: palette.textPrimary,
            ),
          ),
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: Spacing.md),
          SettingsRow(
            leading: Symbols.attach_file,
            title: 'Attachments',
            trailing: Text(
              _fmt(_attSize),
              style: context.mono.copyWith(
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          SettingsRow(
            leading: Symbols.file_download,
            title: 'Export a backup',
            description: 'Saves a copy of the notes database',
            trailing: OutlinedButton(
              onPressed: _export,
              child: const Text('Export'),
            ),
          ),
          const SizedBox(height: Spacing.md),
          SettingsRow(
            leading: Symbols.file_upload,
            title: 'Restore from a backup',
            description: 'Replaces everything on this device',
            leadingColor: palette.error,
            trailing: OutlinedButton(
              onPressed: _restore,
              child: const Text('Restore'),
            ),
          ),
        ],
      ],
    );
  }

  String _fmt(int? bytes) {
    if (bytes == null) return '…';
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
          SnackBar(content: Text('Backup saved to $path')),
        );
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

    final ok = await showDangerConfirmDialog(
      context,
      title: 'Restore from backup?',
      message: 'This replaces every note on this device. A copy of the current '
          'database is saved first.',
      confirmLabel: 'Restore',
    );
    if (!ok) return;

    try {
      final manager = ref.read(databaseManagerProvider);
      await restoreDatabase(manager, sourcePath);
      ref.read(databaseManagerProvider.notifier).state = manager;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes restored.')),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SettingsSection(
      icon: Symbols.info,
      title: 'About',
      children: [
        SettingsRow(
          title: 'Version',
          trailing: Text(
            '1.0.0',
            style: context.mono.copyWith(
              fontWeight: FontWeight.w500,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        SettingsRow(
          title: 'Open source licences',
          trailing: OutlinedButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Easy Notes',
              applicationVersion: '1.0.0',
            ),
            child: const Text('View'),
          ),
        ),
      ],
    );
  }
}
