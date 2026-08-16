import 'package:flutter/material.dart';

/// Warm ink + amber palette for a notes/writing app, on a cream surface.
/// Verified against the ui-ux-pro-max "Notes & Writing App" product profile.
ThemeData buildLightTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF78716C),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFA8A29E),
    onSecondary: Color(0xFF000000),
    tertiary: Color(0xFFD97706),
    onTertiary: Color(0xFF000000),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFBEB),
    onSurface: Color(0xFF0F172A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFEFAF0),
    surfaceContainer: Color(0xFFF6F6F6),
    surfaceContainerHigh: Color(0xFFFFFFFF),
    surfaceContainerHighest: Color(0xFFF0EFEC),
    onSurfaceVariant: Color(0xFF475569),
    outline: Color(0xFFBDB9B4),
    outlineVariant: Color(0xFFEEEDED),
    secondaryContainer: Color(0xFFEDE7DC),
    onSecondaryContainer: Color(0xFF3D3A34),
    primaryContainer: Color(0xFFE7E2DC),
    onPrimaryContainer: Color(0xFF2B2823),
    inverseSurface: Color(0xFF2B2823),
    onInverseSurface: Color(0xFFFFFBEB),
    inversePrimary: Color(0xFFD7CFC5),
  );
  return _build(scheme);
}

ThemeData buildDarkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFD7CFC5),
    onPrimary: Color(0xFF1F1D1A),
    secondary: Color(0xFFA8A29E),
    onSecondary: Color(0xFF1F1D1A),
    tertiary: Color(0xFFF0A93E),
    onTertiary: Color(0xFF1F1400),
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF1F1D1A),
    surface: Color(0xFF17150F),
    onSurface: Color(0xFFEDE9E1),
    surfaceContainerLowest: Color(0xFF0F0D09),
    surfaceContainerLow: Color(0xFF1D1B15),
    surfaceContainer: Color(0xFF221F19),
    surfaceContainerHigh: Color(0xFF2B2823),
    surfaceContainerHighest: Color(0xFF35322B),
    onSurfaceVariant: Color(0xFFC9C4BB),
    outline: Color(0xFF8C877E),
    outlineVariant: Color(0xFF3D3A34),
    secondaryContainer: Color(0xFF3D3A34),
    onSecondaryContainer: Color(0xFFEDE7DC),
    primaryContainer: Color(0xFF41403A),
    onPrimaryContainer: Color(0xFFE7E2DC),
    inverseSurface: Color(0xFFEDE9E1),
    onInverseSurface: Color(0xFF2B2823),
    inversePrimary: Color(0xFF78716C),
  );
  return _build(scheme);
}

ThemeData _build(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape:
          const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.tertiary,
      foregroundColor: scheme.onTertiary,
      elevation: 1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHighest),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28))),
      side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: InputBorder.none,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: scheme.outlineVariant),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8))),
    ),
    dialogTheme: DialogThemeData(
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28))),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  );
}
