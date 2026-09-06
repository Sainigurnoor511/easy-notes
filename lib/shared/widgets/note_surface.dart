import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../models/note_models.dart';

/// The resolved paint for one note: surface, paired border, text and chip fill.
///
/// Per `DESIGN.md` a tinted note keeps `text-primary` — one text color, nine
/// surfaces — so callers never have to pick a foreground.
@immutable
class NoteSurface {
  /// Card / editor background.
  final Color background;

  /// The 1px hairline. On a tint this is the tone's paired border token, never
  /// a neutral grey.
  final Color border;

  /// Title and body text, active icons.
  final Color foreground;

  /// Metadata, timestamps, resting action icons.
  final Color mutedForeground;

  /// Fill for tag chips and nested blocks drawn on this surface.
  final Color chipBackground;

  /// True when the note uses one of the pastel tones rather than plain surface.
  final bool isTinted;

  const NoteSurface({
    required this.background,
    required this.border,
    required this.foreground,
    required this.mutedForeground,
    required this.chipBackground,
    required this.isTinted,
  });

  /// Resolves [colorKey] (the value stored in SQLite) against the active theme.
  ///
  /// Pass `raised: false` for full-bleed surfaces such as the editor canvas,
  /// which sits at canvas level rather than floating above it.
  factory NoteSurface.of(
    BuildContext context,
    String? colorKey, {
    bool raised = true,
  }) {
    final palette = context.palette;
    final brightness = Theme.of(context).brightness;
    final tone = noteColorByKey(colorKey);
    final tint = tone?.surfaceFor(brightness);

    if (tint == null) {
      return NoteSurface(
        background: raised ? palette.surface : palette.canvas,
        border: palette.border,
        foreground: palette.textPrimary,
        mutedForeground: palette.textSecondary,
        chipBackground: palette.surfaceSunken,
        isTinted: false,
      );
    }

    return NoteSurface(
      background: tint,
      border: tone!.borderFor(brightness) ?? palette.border,
      foreground: palette.textPrimary,
      // 0.30 is as far as text can fade toward the lightest wash in the set and
      // still clear 4.5:1.
      mutedForeground: brightness == Brightness.dark
          ? palette.textSecondary
          : Color.lerp(palette.textPrimary, tint, 0.30)!,
      chipBackground: brightness == Brightness.dark
          ? Color.alphaBlend(const Color(0x1AFFFFFF), tint)
          : Color.alphaBlend(const Color(0x99FFFFFF), tint),
      isTinted: true,
    );
  }
}
