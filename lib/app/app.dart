import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_providers.dart';
import '../features/notes/note_actions.dart';
import '../features/reminders/reminder_service.dart';
import '../shared/models/auth_user.dart';
import 'router.dart';
import 'theme.dart';

class EasyNotesApp extends ConsumerStatefulWidget {
  const EasyNotesApp({super.key});

  @override
  ConsumerState<EasyNotesApp> createState() => _EasyNotesAppState();
}

class _EasyNotesAppState extends ConsumerState<EasyNotesApp> {
  @override
  void initState() {
    super.initState();
    // A reminder that opens nothing is a dead end, so tapping one routes to its
    // note. Wired here rather than in the service because the plugin's callback
    // fires without a BuildContext.
    ReminderService.onOpenNote = _openNote;
    ReminderService.onReminderAction = _handleReminderAction;

    final pending = ReminderService.pendingNoteId;
    final pendingAction =
        ReminderService.pendingActionId ?? ReminderService.actionOpen;
    if (pending != null) {
      ReminderService.pendingNoteId = null;
      ReminderService.pendingActionId = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleReminderAction(pending, pendingAction),
      );
    }
  }

  @override
  void dispose() {
    if (ReminderService.onOpenNote == _openNote) {
      ReminderService.onOpenNote = null;
    }
    if (ReminderService.onReminderAction == _handleReminderAction) {
      ReminderService.onReminderAction = null;
    }
    super.dispose();
  }

  Future<void> _handleReminderAction(String noteId, String actionId) async {
    if (!mounted) return;
    if (actionId == ReminderService.actionComplete) {
      await NoteActions.setReminder(ref, noteId, '', null);
      return;
    }
    if (actionId == ReminderService.actionReschedule) {
      ref.read(routerProvider).push('/editor/$noteId?reminder=1');
      return;
    }
    _openNote(noteId);
  }

  void _openNote(String noteId) {
    if (!mounted) return;
    ref.read(routerProvider).push('/editor/$noteId');
  }

  @override
  Widget build(BuildContext context) {
    final themeMode =
        ref.watch(themeControllerProvider).valueOrNull ?? ThemeMode.system;
    final router = ref.watch(routerProvider);

    // Sync on login, connectivity return, and app resume.
    ref.listen(authControllerProvider, (prev, next) {
      final wasSignedIn = prev?.valueOrNull?.status == AuthStatus.signedIn;
      final isSignedIn = next.valueOrNull?.status == AuthStatus.signedIn;
      if (isSignedIn && !wasSignedIn) {
        ref.read(syncControllerProvider.notifier).syncNow();
      }
    });
    ref.listen(connectivityStreamProvider, (prev, next) {
      final online = next.valueOrNull != ConnectivityResult.none;
      final wasOnline =
          prev?.valueOrNull != null &&
          prev!.valueOrNull != ConnectivityResult.none;
      final signedIn =
          ref.read(authControllerProvider).valueOrNull?.status ==
          AuthStatus.signedIn;
      if (online && !wasOnline && signedIn) {
        ref.read(syncControllerProvider.notifier).syncNow();
      }
    });

    return MaterialApp.router(
      title: 'Easy Notes',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
