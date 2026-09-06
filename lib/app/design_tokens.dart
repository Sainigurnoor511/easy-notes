import 'package:flutter/material.dart';

/// Dart mirror of the tokens declared in `DESIGN.md`
/// ("Modern Hybrid Productivity Workspace").
///
/// This file is the single source of truth inside the app. If a value changes
/// here it must change in `DESIGN.md` too — run
/// `npx -p @google/design.md designmd lint DESIGN.md` after editing.
///
/// Nothing in the UI should hardcode a color, radius, shadow or font size.
/// Reach for [AppPalette] (via `context.palette`), [AppRadii], [AppShadows],
/// `Spacing` and the theme's `TextTheme` instead.

/// Font families. Bundled as assets so the identity survives offline.
class AppFonts {
  /// The interface face — everything except metadata and code.
  static const String sans = 'Inter';

  /// Metadata, timestamps, counts, `#tag` chips, IDs, code.
  static const String mono = 'JetBrains Mono';
}

/// Tabular figures, so numbers in columns and timestamps don't jitter.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

/// Corner radii — a Level 2 curvature scale.
class AppRadii {
  /// Drag handles, checkboxes, inline block indicators.
  static const double handle = 4;

  /// Buttons, popovers, cells, code blocks, context menus, inputs.
  static const double base = 8;

  /// Note cards, settings sections, collapsed quick capture.
  static const double md = 12;

  /// Expanded quick capture, floating docks, modal containers.
  static const double lg = 16;

  /// Tag chips, nav pills, view switchers, icon buttons, search field.
  static const double full = 9999;

  static BorderRadius all(double r) => BorderRadius.all(Radius.circular(r));

  static RoundedRectangleBorder shape(double r, {BorderSide? side}) =>
      RoundedRectangleBorder(
        borderRadius: all(r),
        side: side ?? BorderSide.none,
      );
}

/// Motion. Cards lean toward the cursor; they never bounce.
class AppMotion {
  /// Hover and color changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// Layout changes.
  static const Duration base = Duration(milliseconds: 200);

  /// Sheets and dialogs.
  static const Duration slow = Duration(milliseconds: 240);

  static const Curve curve = Curves.easeOutCubic;
}

/// The workspace palette, resolved for one [Brightness].
///
/// Exposed on `BuildContext` through `context.palette` so widgets never have to
/// know which scheme is active.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  // --- Canvas & surfaces ---------------------------------------------------
  /// The workspace backdrop. Never pure white.
  final Color canvas;

  /// Sidebar and secondary panels.
  final Color panel;

  /// Note cards, modals, popovers, elevated blocks.
  final Color surface;

  /// Inputs, chips, sunken rows.
  final Color surfaceSunken;

  /// Hover fill for quiet rows and icon buttons.
  final Color surfaceHover;

  // --- Text ----------------------------------------------------------------
  /// Headings, active body copy, high-contrast labels.
  final Color textPrimary;

  /// Supporting metadata, timestamps, placeholders.
  final Color textSecondary;

  /// Eyebrows, counts, captions, shortcut glyphs, inactive icons.
  ///
  /// Darker than a typical "disabled grey" on purpose: this system sets
  /// metadata at 11–13px, where WCAG AA demands 4.5:1, and this value clears it
  /// at 4.55:1 on the canvas. A lighter tertiary would fail at every size it is
  /// actually used.
  final Color textTertiary;

  /// Text on an inverted surface (snackbars, tooltips).
  final Color textInverse;

  // --- Rules ---------------------------------------------------------------
  /// Hairline container outlines.
  final Color border;

  /// Interactive borders and inputs.
  final Color borderStrong;

  // --- Indigo axis ---------------------------------------------------------
  final Color primary;
  final Color onPrimary;
  final Color primaryHover;

  /// Selection highlights, nav pills, slash-menu selection.
  final Color primaryWash;
  final Color onPrimaryWash;

  /// Informational badges.
  final Color primaryFixed;
  final Color onPrimaryFixed;

  /// 2px keyboard focus ring at an outer offset.
  final Color focusRing;

  // --- Secondary / status --------------------------------------------------
  final Color link;
  final Color error;
  final Color onError;
  final Color errorWash;
  final Color onErrorWash;
  final Color success;
  final Color successWash;
  final Color onSuccessWash;

  /// Base color for ambient shadows.
  final Color shadowBase;

  const AppPalette({
    required this.canvas,
    required this.panel,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.onPrimary,
    required this.primaryHover,
    required this.primaryWash,
    required this.onPrimaryWash,
    required this.primaryFixed,
    required this.onPrimaryFixed,
    required this.focusRing,
    required this.link,
    required this.error,
    required this.onError,
    required this.errorWash,
    required this.onErrorWash,
    required this.success,
    required this.successWash,
    required this.onSuccessWash,
    required this.shadowBase,
  });

  static const AppPalette light = AppPalette(
    canvas: Color(0xFFFBFBFA),
    panel: Color(0xFFF7F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF3F4F3),
    surfaceHover: Color(0xFFEEEEED),
    textPrimary: Color(0xFF191919),
    textSecondary: Color(0xFF646A73),
    textTertiary: Color(0xFF6E747D),
    textInverse: Color(0xFFF1F1F0),
    border: Color(0xFFEBEBEA),
    borderStrong: Color(0xFFDFE0DF),
    primary: Color(0xFF4F46E5),
    onPrimary: Color(0xFFFFFFFF),
    primaryHover: Color(0xFF4338CA),
    primaryWash: Color(0xFFEEF2FF),
    onPrimaryWash: Color(0xFF3730A3),
    primaryFixed: Color(0xFFE2DFFF),
    onPrimaryFixed: Color(0xFF0F0069),
    focusRing: Color(0x334F46E5),
    link: Color(0xFF2563EB),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorWash: Color(0xFFFFDAD6),
    onErrorWash: Color(0xFF93000A),
    success: Color(0xFF059669),
    successWash: Color(0xFFD1FAE5),
    onSuccessWash: Color(0xFF065F46),
    shadowBase: Color(0xFF000000),
  );

  /// Deep obsidian for low-light focus. Hand-tuned, not an inversion.
  static const AppPalette dark = AppPalette(
    canvas: Color(0xFF191919),
    panel: Color(0xFF1C1C1C),
    surface: Color(0xFF242424),
    surfaceSunken: Color(0xFF1F1F1F),
    surfaceHover: Color(0xFF2E2E2E),
    textPrimary: Color(0xFFEDEDEC),
    textSecondary: Color(0xFFA1A5AB),
    textTertiary: Color(0xFF8E949C),
    textInverse: Color(0xFF191919),
    border: Color(0xFF2E2E2E),
    borderStrong: Color(0xFF3D3D3D),
    primary: Color(0xFFA5B4FC),
    onPrimary: Color(0xFF1E1B4B),
    primaryHover: Color(0xFFC7D2FE),
    primaryWash: Color(0xFF272449),
    onPrimaryWash: Color(0xFFC7D2FE),
    primaryFixed: Color(0xFF312E63),
    onPrimaryFixed: Color(0xFFE2DFFF),
    focusRing: Color(0x55A5B4FC),
    link: Color(0xFF93C5FD),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorWash: Color(0xFF3B1512),
    onErrorWash: Color(0xFFFFB4AB),
    success: Color(0xFF6EE7B7),
    successWash: Color(0xFF13322A),
    onSuccessWash: Color(0xFF6EE7B7),
    shadowBase: Color(0xFF000000),
  );

  bool get isDark => canvas.computeLuminance() < 0.5;

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? panel,
    Color? surface,
    Color? surfaceSunken,
    Color? surfaceHover,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textInverse,
    Color? border,
    Color? borderStrong,
    Color? primary,
    Color? onPrimary,
    Color? primaryHover,
    Color? primaryWash,
    Color? onPrimaryWash,
    Color? primaryFixed,
    Color? onPrimaryFixed,
    Color? focusRing,
    Color? link,
    Color? error,
    Color? onError,
    Color? errorWash,
    Color? onErrorWash,
    Color? success,
    Color? successWash,
    Color? onSuccessWash,
    Color? shadowBase,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      panel: panel ?? this.panel,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textInverse: textInverse ?? this.textInverse,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryHover: primaryHover ?? this.primaryHover,
      primaryWash: primaryWash ?? this.primaryWash,
      onPrimaryWash: onPrimaryWash ?? this.onPrimaryWash,
      primaryFixed: primaryFixed ?? this.primaryFixed,
      onPrimaryFixed: onPrimaryFixed ?? this.onPrimaryFixed,
      focusRing: focusRing ?? this.focusRing,
      link: link ?? this.link,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorWash: errorWash ?? this.errorWash,
      onErrorWash: onErrorWash ?? this.onErrorWash,
      success: success ?? this.success,
      successWash: successWash ?? this.successWash,
      onSuccessWash: onSuccessWash ?? this.onSuccessWash,
      shadowBase: shadowBase ?? this.shadowBase,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      canvas: c(canvas, other.canvas),
      panel: c(panel, other.panel),
      surface: c(surface, other.surface),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      surfaceHover: c(surfaceHover, other.surfaceHover),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textInverse: c(textInverse, other.textInverse),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryHover: c(primaryHover, other.primaryHover),
      primaryWash: c(primaryWash, other.primaryWash),
      onPrimaryWash: c(onPrimaryWash, other.onPrimaryWash),
      primaryFixed: c(primaryFixed, other.primaryFixed),
      onPrimaryFixed: c(onPrimaryFixed, other.onPrimaryFixed),
      focusRing: c(focusRing, other.focusRing),
      link: c(link, other.link),
      error: c(error, other.error),
      onError: c(onError, other.onError),
      errorWash: c(errorWash, other.errorWash),
      onErrorWash: c(onErrorWash, other.onErrorWash),
      success: c(success, other.success),
      successWash: c(successWash, other.successWash),
      onSuccessWash: c(onSuccessWash, other.onSuccessWash),
      shadowBase: c(shadowBase, other.shadowBase),
    );
  }
}

/// Ambient, ultra-diffused layering. No heavy drop shadows anywhere.
class AppShadows {
  /// Level 1 — surface cards and panels at rest.
  static List<BoxShadow> e1(AppPalette p) {
    if (p.isDark) return const [];
    return [
      BoxShadow(
        color: p.shadowBase.withValues(alpha: 0.02),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: p.shadowBase.withValues(alpha: 0.04),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Level 2 — hovered cards and floating toolbars.
  static List<BoxShadow> e2(AppPalette p) {
    if (p.isDark) {
      return [
        BoxShadow(
          color: p.shadowBase.withValues(alpha: 0.40),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return [
      BoxShadow(
        color: p.shadowBase.withValues(alpha: 0.05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: p.shadowBase.withValues(alpha: 0.03),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Level 3 — menus, popovers, quick capture.
  static List<BoxShadow> e3(AppPalette p) {
    if (p.isDark) {
      return [
        BoxShadow(
          color: p.shadowBase.withValues(alpha: 0.50),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
    }
    return [
      BoxShadow(
        color: p.shadowBase.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: p.shadowBase.withValues(alpha: 0.04),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Level 4 — modal editors.
  static List<BoxShadow> e4(AppPalette p) {
    return [
      BoxShadow(
        color: p.shadowBase.withValues(alpha: p.isDark ? 0.6 : 0.12),
        blurRadius: 48,
        offset: const Offset(0, 20),
      ),
    ];
  }
}

/// Convenience access to the palette and the tokens Material's [TextTheme]
/// can't express.
extension AppThemeX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  TextTheme get texts => Theme.of(this).textTheme;

  /// `label-sm` uppercase with wide tracking — section eyebrows.
  TextStyle get eyebrow => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.08 * 11,
        color: palette.textTertiary,
      );

  /// `code-sm` — metadata, timestamps, counts, `#tag` chips, IDs.
  TextStyle get mono => TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        color: palette.textSecondary,
      );

  /// `display` — the largest type in the app, once per screen at most.
  TextStyle get display => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 32,
        color: palette.textPrimary,
      );
}
