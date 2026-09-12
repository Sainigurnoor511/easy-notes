import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';

Future<Uint8List?> showDrawingEditor(BuildContext context) {
  return showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _DrawingEditor(),
  );
}

class _DrawingEditor extends StatefulWidget {
  const _DrawingEditor();

  @override
  State<_DrawingEditor> createState() => _DrawingEditorState();
}

class _DrawingEditorState extends State<_DrawingEditor> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  bool _saving = false;

  void _startStroke(DragStartDetails details) {
    setState(() => _strokes.add([details.localPosition]));
  }

  void _extendStroke(DragUpdateDetails details) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(details.localPosition));
  }

  Future<void> _save() async {
    if (_strokes.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _canvasKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (mounted && data != null) {
        Navigator.pop(context, data.buffer.asUint8List());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Drawing'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.undo),
            tooltip: 'Undo stroke',
            onPressed:
                _strokes.isEmpty
                    ? null
                    : () => setState(() => _strokes.removeLast()),
          ),
          IconButton(
            icon: const Icon(Symbols.delete_sweep),
            tooltip: 'Clear drawing',
            onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
          ),
          const SizedBox(width: Spacing.xs),
          FilledButton.icon(
            onPressed: _strokes.isEmpty || _saving ? null : _save,
            icon:
                _saving
                    ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Symbols.check, size: 18),
            label: const Text('Save'),
          ),
          const SizedBox(width: Spacing.md),
        ],
      ),
      body: ColoredBox(
        color: palette.surfaceSunken,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Center(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: RepaintBoundary(
                key: _canvasKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _startStroke,
                  onPanUpdate: _extendStroke,
                  child: CustomPaint(
                    foregroundPainter: _DrawingPainter(_strokes),
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;

  const _DrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFF202124)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
