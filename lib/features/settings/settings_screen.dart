import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

/// Settings & Google Drive sync.
///
/// A breadcrumbed page banner, then Level 1 section cards: each has a 40px icon
/// tile, a `headline-sm` title, a `body-sm` description, and sunken rows for the
/// individual controls.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to Google.')),
        );
      }
    });

    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final gutter = wide ? Spacing.xxl : Spacing.gutter;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SingleChildScrollView(
        padding:
            EdgeInsets.fromLTRB(gutter, Spacing.xl, gutter, Spacing.xxxl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.form),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PageBanner(),
                const SizedBox(height: Spacing.xl),
                const _AccountSection(),
                if (!kIsWeb) ...[
                  const SizedBox(height: Spacing.lg),
                  const _SyncSection(),
                ],
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

/// Breadcrumb, `headline-lg` title, description, and a live status pill.
class _PageBanner extends ConsumerWidget {
  const _PageBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final sync = ref.watch(syncControllerProvider);
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final connected = auth?.status == AuthStatus.signedIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Workspace',
              style: context.texts.labelMedium
                  ?.copyWith(color: palette.textTertiary),
            ),
            Icon(Symbols.chevron_right, size: 14, color: palette.textTertiary),
            Text(
              'Settings & storage',
              style: context.texts.labelMedium?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings & Google Drive sync',
                      style: context.texts.headlineLarge),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Manage local caching, Drive backup, appearance and '
                    'workspace storage.',
                    style: context.texts.bodySmall
                        ?.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.lg),
            StatusPill(
              label: sync.status == SyncStatus.failed
                  ? 'Sync failed'
                  : connected
                      ? 'Offline engine ready'
                      : 'Local only',
              background: palette.surfaceSunken,
              foreground: sync.status == SyncStatus.failed
                  ? palette.error
                  : connected
                      ? palette.success
                      : palette.textSecondary,
              dot: true,
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        Divider(color: palette.border, height: 1),
      ],
    );
  }
}

/// The connected Google account, or the connect prompt.
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final authAsync = ref.watch(authControllerProvider);
    final auth = authAsync.valueOrNull;
    final user = auth?.user;
    final connected = auth?.status == AuthStatus.signedIn ||
        auth?.status == AuthStatus.offline;

    if (!connected || user == null) {
      return SettingsSection(
        icon: Symbols.account_circle,
        title: 'Account',
        description: 'Notes stay on this device until you connect Drive.',
        children: [
          SettingsRow(
            leading: Symbols.cloud_off,
            title: 'Not connected',
            description: 'Connect Google Drive to back up your notes and sync '
                'them across devices. Nothing leaves this device until you do.',
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
          ),
        ],
      );
    }

    final photoUrl = user.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return SurfacePanel(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.primaryWash,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.primaryFixed, width: 2),
                  image: hasPhoto
                      ? DecorationImage(
                          image: NetworkImage(photoUrl), fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: hasPhoto
                    ? null
                    : Icon(Symbols.person,
                        size: 26, color: palette.onPrimaryWash),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    auth?.status == AuthStatus.signedIn
                        ? Symbols.verified
                        : Symbols.cloud_off,
                    size: 15,
                    color: auth?.status == AuthStatus.signedIn
                        ? palette.primary
                        : palette.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name.isEmpty ? 'Google account' : user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    StatusPill(
                      label: auth?.status == AuthStatus.signedIn
                          ? 'Connected'
                          : 'Offline',
                      background: auth?.status == AuthStatus.signedIn
                          ? palette.primaryFixed
                          : palette.surfaceSunken,
                      foreground: auth?.status == AuthStatus.signedIn
                          ? palette.onPrimaryFixed
                          : palette.textSecondary,
                    ),
                  ],
                ),
                if (user.email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xxs),
                    child: Text(
                      user.email,
                      style: context.mono.copyWith(color: palette.textSecondary),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.xxs),
                  child: Text(
                    auth?.status == AuthStatus.signedIn
                        ? 'Drive AppData sandbox · encrypted in transit'
                        : 'Will reconnect when Google is reachable again',
                    style: context.texts.labelSmall
                        ?.copyWith(color: palette.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          GhostIconButton(
            icon: Symbols.logout,
            tooltip: 'Disconnect account',
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

/// Drive sync: a state callout, the last-sync stamp, and a sync action.
class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final sync = ref.watch(syncControllerProvider);
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final connected = auth?.status == AuthStatus.signedIn;

    final (calloutBg, calloutFg, calloutIcon, headline, detail) =
        switch (sync.status) {
      SyncStatus.failed => (
          palette.errorWash,
          palette.onErrorWash,
          Symbols.error,
          'Sync failed · working offline',
          sync.error ?? 'Your local notes are safe. We will retry when you '
              'are back online.',
        ),
      SyncStatus.syncing => (
          palette.primaryWash,
          palette.onPrimaryWash,
          Symbols.sync,
          'Syncing with Drive…',
          'Uploading changed notes and attachments.',
        ),
      SyncStatus.offline => (
          palette.surfaceSunken,
          palette.textSecondary,
          Symbols.cloud_off,
          'Offline · 100% local',
          'Changes are cached locally and sync silently when the connection '
              'resumes.',
        ),
      SyncStatus.synced => (
          palette.successWash,
          palette.onSuccessWash,
          Symbols.check_circle,
          'Drive sync active · 100% offline ready',
          'All notes are cached on this device. Changes sync silently in the '
              'background.',
        ),
      SyncStatus.idle => (
          palette.surfaceSunken,
          palette.textSecondary,
          Symbols.cloud,
          connected ? 'Drive connected' : 'Local only',
          connected
              ? 'Ready to sync. Nothing has changed since the last run.'
              : 'Connect Drive above to back up this workspace.',
        ),
    };

    return SettingsSection(
      icon: Symbols.cloud_sync,
      title: 'Google Drive & offline sync',
      description: 'Bi-directional replication through the Drive AppData '
          'sandbox',
      headerAction: FilledButton.icon(
        onPressed: sync.status == SyncStatus.syncing
            ? null
            : () => ref.read(syncControllerProvider.notifier).syncNow(),
        icon: const Icon(Symbols.sync, size: 18),
        label: const Text('Sync now'),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: calloutBg,
            borderRadius: AppRadii.all(AppRadii.md),
            border: Border.all(color: calloutFg.withValues(alpha: 0.16)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(calloutIcon, size: 20, color: calloutFg),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: context.texts.headlineSmall
                          ?.copyWith(color: calloutFg),
                    ),
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      detail,
                      style: context.texts.bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        SettingsRow(
          leading: Symbols.history,
          title: 'Last synced',
          description: 'Deltas are pushed within moments of an edit.',
          trailing: Text(
            sync.lastSync == null
                ? 'Never'
                : DateFormat('d MMM, HH:mm:ss').format(sync.lastSync!),
            style: context.mono.copyWith(
              fontWeight: FontWeight.w500,
              color: palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Theme mode as three preview cards, matching the reference's picker.
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(themeControllerProvider).valueOrNull ?? ThemeMode.system;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

    final cards = [
      _ThemeCard(
        mode: ThemeMode.light,
        label: 'Light',
        caption: 'Calm, clear daytime contrast',
        selected: mode == ThemeMode.light,
        onTap: () => ref.read(themeControllerProvider.notifier).set(
              ThemeMode.light,
            ),
      ),
      _ThemeCard(
        mode: ThemeMode.dark,
        label: 'Dark',
        caption: 'Deep obsidian for low-light focus',
        selected: mode == ThemeMode.dark,
        onTap: () => ref.read(themeControllerProvider.notifier).set(
              ThemeMode.dark,
            ),
      ),
      _ThemeCard(
        mode: ThemeMode.system,
        label: 'System',
        caption: 'Matches your OS preference',
        selected: mode == ThemeMode.system,
        onTap: () => ref.read(themeControllerProvider.notifier).set(
              ThemeMode.system,
            ),
      ),
    ];

    return SettingsSection(
      icon: Symbols.palette,
      title: 'Appearance',
      description: 'Tailor canvas contrast and note-card density',
      children: [
        Text(
          'Theme mode',
          style: context.texts.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Spacing.md),
        if (wide)
          Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: Spacing.md),
                Expanded(child: cards[i]),
              ],
            ],
          )
        else
          Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: Spacing.md),
                cards[i],
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
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.mode,
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final light = AppPalette.light;
    final dark = AppPalette.dark;

    return InkWell(
      borderRadius: AppRadii.all(AppRadii.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: AppRadii.all(AppRadii.md),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppShadows.e1(palette) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _preview(light, dark),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.texts.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  selected
                      ? Symbols.radio_button_checked
                      : Symbols.radio_button_unchecked,
                  size: 19,
                  color: selected ? palette.primary : palette.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: Spacing.xxs),
            Text(
              caption,
              style:
                  context.texts.labelSmall?.copyWith(color: palette.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(AppPalette light, AppPalette dark) {
    final p = mode == ThemeMode.dark ? dark : light;
    final bars = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(p, 0.34),
        const SizedBox(height: 5),
        _bar(p, 1.0),
        const SizedBox(height: 5),
        _bar(p, 0.66),
      ],
    );

    final child = Container(
      height: 62,
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: p.canvas,
        borderRadius: AppRadii.all(AppRadii.base),
        border: Border.all(color: p.border),
      ),
      alignment: Alignment.topLeft,
      child: bars,
    );

    if (mode != ThemeMode.system) return child;

    // System mode previews both halves.
    return SizedBox(
      height: 62,
      child: ClipRRect(
        borderRadius: AppRadii.all(AppRadii.base),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(Spacing.sm),
                color: light.canvas,
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_bar(light, 0.5), const SizedBox(height: 5), _bar(light, 1)],
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(Spacing.sm),
                color: dark.canvas,
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_bar(dark, 0.5), const SizedBox(height: 5), _bar(dark, 1)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(AppPalette p, double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: p.surfaceHover,
          borderRadius: AppRadii.all(AppRadii.handle),
        ),
      ),
    );
  }
}

/// Local footprint with progress bars, plus export/restore.
class _StorageSection extends ConsumerStatefulWidget {
  const _StorageSection();

  @override
  ConsumerState<_StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<_StorageSection> {
  /// Indicative local budget so the bars have a scale to read against.
  static const int _localQuota = 500 * 1024 * 1024;

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
      title: 'Storage & backup',
      description: 'Local cache footprint and database snapshots',
      headerAction: GhostIconButton(
        icon: Symbols.refresh,
        tooltip: 'Recalculate',
        onPressed: _refresh,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: AppRadii.all(AppRadii.md),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              LabelledProgress(
                icon: Symbols.smartphone,
                label: 'Notes database',
                value: '${_fmt(_dbSize)} / 500 MB',
                fraction: (_dbSize ?? 0) / _localQuota,
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: Spacing.md),
                LabelledProgress(
                  icon: Symbols.attach_file,
                  label: 'Attachments',
                  value: '${_fmt(_attSize)} / 500 MB',
                  fraction: (_attSize ?? 0) / _localQuota,
                  color: palette.link,
                ),
              ],
            ],
          ),
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: Spacing.md),
          SettingsRow(
            leading: Symbols.file_download,
            title: 'Export database',
            description: 'Copies the SQLite file to local storage',
            trailing: OutlinedButton(
              onPressed: _export,
              child: const Text('Export'),
            ),
          ),
          const SizedBox(height: Spacing.md),
          SettingsRow(
            leading: Symbols.file_upload,
            title: 'Restore from backup',
            description: 'Replaces local data with a backup file',
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
          SnackBar(content: Text('Database exported to $path')),
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
      title: 'Restore database?',
      message: 'This replaces your current local data. A backup of the current '
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
          const SnackBar(content: Text('Database restored.')),
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
      description: 'Easy Notes · offline-first workspace',
      children: [
        SettingsRow(
          leading: Symbols.tag,
          title: 'App version',
          description: 'Built from the Modern Hybrid Productivity Workspace '
              'design system',
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
          leading: Symbols.description,
          title: 'Open source licences',
          description: 'Packages bundled with this app',
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
