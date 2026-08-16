import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_providers.dart';
import '../shared/models/auth_user.dart';
import 'router.dart';
import 'theme.dart';

class EasyNotesApp extends ConsumerWidget {
  const EasyNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider).valueOrNull ?? ThemeMode.system;
    final router = ref.watch(routerProvider);

    // Sync on login, connectivity return, and app resume.
    ref.listen(authControllerProvider, (prev, next) {
      final wasSignedIn =
          prev?.valueOrNull?.status == AuthStatus.signedIn;
      final isSignedIn = next.valueOrNull?.status == AuthStatus.signedIn;
      if (isSignedIn && !wasSignedIn) {
        ref.read(syncControllerProvider.notifier).syncNow();
      }
    });
    ref.listen(connectivityStreamProvider, (prev, next) {
      final online = next.valueOrNull != ConnectivityResult.none;
      final wasOnline =
          prev?.valueOrNull != null && prev!.valueOrNull != ConnectivityResult.none;
      final signedIn =
          ref.read(authControllerProvider).valueOrNull?.status == AuthStatus.signedIn;
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