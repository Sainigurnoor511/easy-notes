import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';
import 'spacing.dart';

/// Themes built from the tokens in `DESIGN.md`.
///
/// Every value here traces back to [AppPalette], [AppRadii], [AppShadows] or
/// [Spacing]. Material's tonal-elevation machinery is deliberately switched off
/// (`surfaceTintColor: transparent`, `elevation: 0`) because this system picks
/// its surfaces explicitly.
ThemeData buildLightTheme() => _build(AppPalette.light, Brightness.light);

ThemeData buildDarkTheme() => _build(AppPalette.dark, Brightness.dark);

/// Maps the palette onto Material's [ColorScheme] so stock widgets inherit the
/// identity for free.
ColorScheme _scheme(AppPalette p, Brightness brightness) {
  return ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryWash,
    onPrimaryContainer: p.onPrimaryWash,
    secondary: p.primary,
    onSecondary: p.onPrimary,
    secondaryContainer: p.primaryWash,
    onSecondaryContainer: p.onPrimaryWash,
    tertiary: p.link,
    onTertiary: p.onPrimary,
    tertiaryContainer: p.primaryFixed,
    onTertiaryContainer: p.onPrimaryFixed,
    error: p.error,
    onError: p.onError,
    errorContainer: p.errorWash,
    onErrorContainer: p.onErrorWash,
    surface: p.canvas,
    onSurface: p.textPrimary,
    surfaceDim: p.surfaceHover,
    surfaceBright: p.surface,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.panel,
    surfaceContainer: p.surfaceSunken,
    surfaceContainerHigh: p.surfaceHover,
    surfaceContainerHighest: p.surfaceHover,
    onSurfaceVariant: p.textSecondary,
    outline: p.borderStrong,
    outlineVariant: p.border,
    shadow: p.shadowBase,
    scrim: p.shadowBase,
    inverseSurface: p.textPrimary,
    onInverseSurface: p.textInverse,
    inversePrimary: p.primaryWash,
  );
}

/// The type scale. Inter across the interface with tabular figures; JetBrains
/// Mono is applied per-widget via `context.mono`, never through the TextTheme.
TextTheme _textTheme(AppPalette p) {
  TextStyle t(
    double size,
    FontWeight weight,
    double lineHeightPx, {
    double trackingEm = 0,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: size,
        fontWeight: weight,
        height: lineHeightPx / size,
        letterSpacing: trackingEm * size,
        color: color ?? p.textPrimary,
        fontFeatures: kTabularFigures,
      );

  return TextTheme(
    // display — 32/40/700/-0.02em
    displayLarge: t(32, FontWeight.w700, 40, trackingEm: -0.02),
    displayMedium: t(32, FontWeight.w700, 40, trackingEm: -0.02),
    displaySmall: t(28, FontWeight.w700, 36, trackingEm: -0.02),

    // headline-lg / md / sm
    headlineLarge: t(24, FontWeight.w600, 32, trackingEm: -0.015),
    headlineMedium: t(20, FontWeight.w600, 28, trackingEm: -0.01),
    headlineSmall: t(16, FontWeight.w600, 24, trackingEm: -0.005),

    // Titles reuse the headline steps so stock widgets land in the scale.
    titleLarge: t(20, FontWeight.w600, 28, trackingEm: -0.01),
    titleMedium: t(16, FontWeight.w600, 24, trackingEm: -0.005),
    titleSmall: t(14, FontWeight.w600, 20),

    // body-lg / md / sm
    bodyLarge: t(16, FontWeight.w400, 26, trackingEm: -0.005),
    bodyMedium: t(14, FontWeight.w400, 22),
    bodySmall: t(13, FontWeight.w400, 18, color: p.textSecondary),

    // label-md / sm
    labelLarge: t(14, FontWeight.w500, 20, trackingEm: 0.01),
    labelMedium: t(12, FontWeight.w500, 16, trackingEm: 0.01),
    labelSmall: t(11, FontWeight.w500, 14, trackingEm: 0.02,
        color: p.textSecondary),
  );
}

/// Material Symbols Outlined axes, pinned to the reference values. `FILL` stays
/// at 0 here; widgets raise it to 1 for an active state.
IconThemeData _icons(AppPalette p) => IconThemeData(
      color: p.textSecondary,
      size: 20,
      fill: 0,
      weight: 400,
      grade: 0,
      opticalSize: 24,
    );

ThemeData _build(AppPalette p, Brightness brightness) {
  final scheme = _scheme(p, brightness);
  final text = _textTheme(p);
  final hairline = BorderSide(color: p.border);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[p],
    fontFamily: AppFonts.sans,
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: p.canvas,
    canvasColor: p.canvas,
    dividerColor: p.border,
    splashFactory: InkSparkle.splashFactory,

    // --- Chrome -------------------------------------------------------------
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      foregroundColor: p.textPrimary,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: Sizes.topBar,
      titleTextStyle: text.headlineMedium,
      iconTheme: _icons(p),
      actionsIconTheme: _icons(p),
      systemOverlayStyle: brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    ),
    iconTheme: _icons(p),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),

    // --- Surfaces -----------------------------------------------------------
    cardTheme: CardThemeData(
      elevation: 0,
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: AppRadii.shape(AppRadii.md, side: hairline),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: AppRadii.shape(AppRadii.lg, side: BorderSide(color: p.border)),
      titleTextStyle: text.headlineMedium,
      contentTextStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
      insetPadding: const EdgeInsets.all(Spacing.xl),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: p.borderStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadii.lg)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: p.shadowBase.withValues(alpha: 0.08),
      textStyle: text.bodyMedium,
      shape: AppRadii.shape(
        AppRadii.base,
        side: BorderSide(color: p.borderStrong),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(3),
        shape: WidgetStatePropertyAll(
          AppRadii.shape(AppRadii.base, side: BorderSide(color: p.borderStrong)),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: p.textPrimary,
        borderRadius: AppRadii.all(AppRadii.handle + 2),
      ),
      textStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w500,
        color: p.textInverse,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.textPrimary,
      contentTextStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        height: 22 / 14,
        color: p.textInverse,
      ),
      actionTextColor: p.isDark ? p.primary : p.primaryWash,
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      insetPadding: const EdgeInsets.all(Spacing.lg),
      shape: AppRadii.shape(AppRadii.base),
    ),

    // --- Actions ------------------------------------------------------------
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      elevation: 2,
      focusElevation: 3,
      hoverElevation: 3,
      highlightElevation: 2,
      shape: AppRadii.shape(AppRadii.full),
      extendedTextStyle: text.labelLarge?.copyWith(color: p.onPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return p.textTertiary.withValues(alpha: 0.25);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return p.primaryHover;
          }
          return p.primary;
        }),
        foregroundColor: WidgetStatePropertyAll(p.onPrimary),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        minimumSize: const WidgetStatePropertyAll(Size(0, kMinTouchTarget)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Spacing.lg),
        ),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: WidgetStatePropertyAll(AppRadii.shape(AppRadii.base)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return p.textTertiary;
          return p.primary;
        }),
        overlayColor: WidgetStatePropertyAll(p.primary.withValues(alpha: 0.08)),
        minimumSize: const WidgetStatePropertyAll(Size(0, kMinTouchTarget)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Spacing.md),
        ),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: WidgetStatePropertyAll(AppRadii.shape(AppRadii.base)),
      ),
    ),
    // Ghost/tertiary button: transparent with a hairline, not a Material outline.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return p.surfaceSunken;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStatePropertyAll(p.textPrimary),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        minimumSize: const WidgetStatePropertyAll(Size(0, kMinTouchTarget)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Spacing.md + 2),
        ),
        textStyle: WidgetStatePropertyAll(text.labelMedium),
        shape: WidgetStatePropertyAll(AppRadii.shape(AppRadii.base)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return p.textTertiary;
          if (states.contains(WidgetState.hovered)) return p.textPrimary;
          return p.textSecondary;
        }),
        overlayColor: WidgetStatePropertyAll(
          p.textPrimary.withValues(alpha: 0.04),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(kMinTouchTarget, kMinTouchTarget),
        ),
        shape: WidgetStatePropertyAll(AppRadii.shape(AppRadii.full)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.surface;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.textPrimary;
          return p.textSecondary;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        textStyle: WidgetStatePropertyAll(text.labelMedium),
        shape: WidgetStatePropertyAll(AppRadii.shape(AppRadii.base)),
      ),
    ),

    // --- Inputs -------------------------------------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceSunken,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.md,
      ),
      hintStyle: text.bodyMedium?.copyWith(color: p.textTertiary),
      labelStyle: text.labelMedium?.copyWith(color: p.textSecondary),
      floatingLabelStyle: text.labelMedium?.copyWith(color: p.primary),
      border: OutlineInputBorder(
        borderRadius: AppRadii.all(AppRadii.base),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.all(AppRadii.base),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.all(AppRadii.base),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadii.all(AppRadii.base),
        borderSide: BorderSide(color: p.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadii.all(AppRadii.base),
        borderSide: BorderSide(color: p.error, width: 1.5),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return p.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(p.onPrimary),
      side: BorderSide(color: p.borderStrong, width: 1.5),
      shape: AppRadii.shape(AppRadii.handle),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return p.primary;
        return p.borderStrong;
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return p.surface;
        return p.surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return p.primary;
        return p.surfaceHover;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return p.borderStrong;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.primary,
      inactiveTrackColor: p.surfaceHover,
      thumbColor: p.primary,
      trackHeight: 4,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.surfaceHover,
      circularTrackColor: Colors.transparent,
      linearMinHeight: 6,
      strokeWidth: 2.5,
    ),

    // --- Content ------------------------------------------------------------
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceSunken,
      selectedColor: p.primaryWash,
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 12,
        height: 16 / 12,
        color: p.textSecondary,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      shape: AppRadii.shape(AppRadii.full),
      showCheckmark: false,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      textColor: p.textPrimary,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
      minVerticalPadding: Spacing.md,
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      shape: AppRadii.shape(AppRadii.base),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: p.textSecondary,
      textColor: p.textPrimary,
      shape: AppRadii.shape(AppRadii.md),
      collapsedShape: AppRadii.shape(AppRadii.md),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: p.primaryWash,
      indicatorShape: AppRadii.shape(AppRadii.full),
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: p.onPrimaryWash, size: 20);
        }
        return IconThemeData(color: p.textSecondary, size: 20);
      }),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      headerBackgroundColor: p.surfaceSunken,
      headerForegroundColor: p.textPrimary,
      shape: AppRadii.shape(AppRadii.lg),
      todayBorder: BorderSide(color: p.primary),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: p.surface,
      elevation: 0,
      dialBackgroundColor: p.surfaceSunken,
      shape: AppRadii.shape(AppRadii.lg),
      hourMinuteShape: AppRadii.shape(AppRadii.base),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(p.borderStrong),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(AppRadii.handle),
      crossAxisMargin: 2,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.primary,
      selectionColor: p.primary.withValues(alpha: 0.20),
      selectionHandleColor: p.primary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
