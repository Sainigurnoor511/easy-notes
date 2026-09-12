/// Spacing scale from `DESIGN.md`. Every padding, gap and margin adheres to a
/// 4px base increment. `sm` (8px) groups elements inside a control; `lg` (16px)
/// is card body padding.
class Spacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Canvas gutter at the narrow end of the responsive range.
  static const double gutter = 20;
}

/// Layout breakpoints (logical px).
class Breakpoints {
  static const double mobile = 375;
  static const double tablet = 768;
  static const double laptop = 1024;
  static const double wide = 1440;
}

/// Fixed structural widths.
class Sizes {
  /// The navigation drawer, expanded.
  static const double sidebar = 240;

  /// The navigation drawer, icon-only.
  ///
  /// Matches the top bar's leading slot — 8px gutter plus a 40px target — so a
  /// collapsed rail's glyphs sit directly under the drawer toggle instead of
  /// half a button to its right.
  static const double sidebarCollapsed = 56;

  /// The top bar.
  static const double topBar = 56;

  /// Quick capture, centred on the canvas.
  static const double quickCapture = 600;

  /// Forms and settings columns.
  static const double form = 960;

  /// The note editor's document sheet.
  static const double sheet = 840;

  /// The top bar's inline search field.
  static const double search = 560;

  /// Minimum masonry column width before dropping a column.
  static const double minCardWidth = 240;

  /// Minimum masonry column width on phones, where the wall stays two columns.
  static const double minCardWidthCompact = 150;
}

/// Minimum interactive target. Glyphs render at 18–20px inside it.
const double kMinTouchTarget = 40;

/// Minimum interactive target on touch devices.
const double kMinTouchTargetTouch = 44;
