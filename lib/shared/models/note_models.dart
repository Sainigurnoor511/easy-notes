import 'dart:convert';

import 'package:flutter/material.dart';

enum NoteType { text, checklist, document }

enum BlockType {
  text,
  heading,
  bullet,
  numberedList,
  checklist,
  quote,
  code,
  divider,
  image,
  table;

  static BlockType fromDb(String v) => BlockType.values
      .firstWhere((e) => e.name == v, orElse: () => BlockType.text);

  String get dbName => name;
}

/// Content for a table block, stored as JSON in `blocks.content`.
class TableBlockData {
  List<String> columns;
  List<List<String>> rows;

  TableBlockData({List<String>? columns, List<List<String>>? rows})
      : columns = columns ?? <String>['Column 1', 'Column 2'],
        rows = rows ?? <List<String>>[<String>['', ''], <String>['', '']];

  factory TableBlockData.fromJson(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final columns = (map['columns'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      final rows = (map['rows'] as List<dynamic>? ?? const [])
          .map((r) => (r as List<dynamic>).map((e) => e.toString()).toList())
          .toList();
      return TableBlockData(columns: columns, rows: rows);
    } catch (_) {
      return TableBlockData();
    }
  }

  String toJson() => jsonEncode({'columns': columns, 'rows': rows});

  void addRow() => rows.add(List.filled(columns.length, ''));

  void addColumn() {
    columns.add('Column ${columns.length + 1}');
    for (final r in rows) {
      r.add('');
    }
  }

  void removeRow(int index) {
    if (rows.length > 1) rows.removeAt(index);
  }

  void removeColumn(int index) {
    if (columns.length > 1) {
      columns.removeAt(index);
      for (final r in rows) {
        r.removeAt(index);
      }
    }
  }
}

/// A calibrated pastel tone from `DESIGN.md`.
///
/// Each tone is a *pair*: a surface wash plus a slightly more saturated
/// border/highlight, so a tinted card never shows a neutral grey edge. Every
/// tone carries `text-primary` at well above 4.5:1 — one text color, nine
/// surfaces. A tone that needs white text is too dark for this system.
///
/// Dark-mode variants are re-derived in the same hue family at roughly 12%
/// luminance rather than inverted, because a `#FEF9C3` card at night is a
/// flashlight.
///
/// [key] is what lands in SQLite, so the keys are frozen for backwards
/// compatibility even though the labels and swatches have been retuned.
class NoteColor {
  final String key;
  final String label;
  final Color? lightSurface;
  final Color? lightBorder;
  final Color? darkSurface;

  const NoteColor(
    this.key,
    this.label, {
    this.lightSurface,
    this.lightBorder,
    this.darkSurface,
  });

  /// The "Default" entry paints on the theme surface instead of a tone.
  bool get isDefault => lightSurface == null;

  Color? surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  /// The paired border for [brightness]. Dark tones lighten their own surface
  /// instead of carrying a separate token.
  Color? borderFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      final s = darkSurface;
      if (s == null) return null;
      return Color.alphaBlend(const Color(0x26FFFFFF), s);
    }
    return lightBorder;
  }
}

const List<NoteColor> kNoteColors = [
  NoteColor('default', 'White'),
  NoteColor('red', 'Coral',
      lightSurface: Color(0xFFFFE4E6),
      lightBorder: Color(0xFFFECDD3),
      darkSurface: Color(0xFF3B1D20)),
  NoteColor('orange', 'Peach',
      lightSurface: Color(0xFFFFEDD5),
      lightBorder: Color(0xFFFED7AA),
      darkSurface: Color(0xFF3A2716)),
  NoteColor('yellow', 'Cream',
      lightSurface: Color(0xFFFEF9C3),
      lightBorder: Color(0xFFFEF08A),
      darkSurface: Color(0xFF3A3417)),
  NoteColor('green', 'Mint',
      lightSurface: Color(0xFFDCFCE7),
      lightBorder: Color(0xFFBBF7D0),
      darkSurface: Color(0xFF17321F)),
  NoteColor('teal', 'Teal',
      lightSurface: Color(0xFFCCFBF1),
      lightBorder: Color(0xFF99F6E4),
      darkSurface: Color(0xFF123331)),
  NoteColor('blue', 'Sky',
      lightSurface: Color(0xFFE0F2FE),
      lightBorder: Color(0xFFBAE6FD),
      darkSurface: Color(0xFF152B3D)),
  NoteColor('purple', 'Lavender',
      lightSurface: Color(0xFFF3E8FF),
      lightBorder: Color(0xFFE9D5FF),
      darkSurface: Color(0xFF2A2140)),
  NoteColor('pink', 'Pink',
      lightSurface: Color(0xFFFCE7F3),
      lightBorder: Color(0xFFFBCFE8),
      darkSurface: Color(0xFF37182B)),
];

NoteColor? noteColorByKey(String? key) {
  if (key == null) return null;
  for (final c in kNoteColors) {
    if (c.key == key) return c;
  }
  return null;
}