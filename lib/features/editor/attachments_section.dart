import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/widgets/app_widgets.dart';
import 'attachment_preview_io.dart'
    if (dart.library.js_interop) 'attachment_preview_web.dart';
import 'audio_recorder_io.dart'
    if (dart.library.js_interop) 'audio_recorder_web.dart';
import 'drawing_editor.dart';

bool isImageAttachment(Attachment attachment) {
  final value = attachment.mimeType?.toLowerCase().trim() ?? '';
  return value.startsWith('image/') ||
      const {
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'bmp',
        'heic',
      }.contains(value);
}

Future<void> _removeAttachment(WidgetRef ref, Attachment attachment) async {
  await ref.read(attachmentsDaoProvider).remove(attachment.id);
  await ref.read(attachmentStorageProvider).deleteFile(attachment.localPath);
  await ref.read(notesDaoProvider).touch(attachment.noteId);
  unawaited(ref.read(syncControllerProvider.notifier).syncNow());
}

class AttachmentImageStrip extends ConsumerWidget {
  final String noteId;

  const AttachmentImageStrip({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Attachment>>(
      stream: ref.watch(attachmentsDaoProvider).watchForNote(noteId),
      builder: (context, snapshot) {
        final images =
            (snapshot.data ?? const <Attachment>[])
                .where(isImageAttachment)
                .toList();
        if (images.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.xl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = images.length == 1 ? 1 : 2;
              final rows = (images.length / columns).ceil();
              final gap = Spacing.sm;
              final tileHeight =
                  images.length == 1
                      ? 240.0
                      : images.length == 2
                      ? 184.0
                      : 160.0;
              final itemWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;

              return SizedBox(
                height: rows * tileHeight + (rows - 1) * gap,
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  crossAxisCount: columns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  childAspectRatio: itemWidth / tileHeight,
                  children: [
                    for (final image in images)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: context.palette.surfaceSunken,
                              borderRadius: AppRadii.all(AppRadii.md),
                              border: Border.all(color: context.palette.border),
                            ),
                            child: attachmentImage(
                              image.localPath,
                              width: itemWidth,
                              height: tileHeight,
                              borderRadius: AppRadii.all(AppRadii.md),
                            ),
                          ),
                          Positioned(
                            top: Spacing.sm,
                            right: Spacing.sm,
                            child: GhostIconButton(
                              icon: Symbols.close,
                              tooltip: 'Remove image',
                              iconSize: 20,
                              target: 38,
                              background: Colors.black.withValues(alpha: 0.58),
                              color: Colors.white,
                              onPressed: () => _removeAttachment(ref, image),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class AttachmentsSection extends ConsumerWidget {
  final String noteId;

  const AttachmentsSection({super.key, required this.noteId});

  static Future<void> drawAndAdd(
    BuildContext context,
    WidgetRef ref,
    String noteId,
  ) async {
    final bytes = await showDrawingEditor(context);
    if (bytes == null) return;
    final fileName = 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = await ref
        .read(attachmentStorageProvider)
        .saveBytes(noteId: noteId, bytes: bytes, fileName: fileName);
    try {
      await _register(
        ref,
        noteId,
        fileName: fileName,
        path: path,
        mimeType: 'image/png',
      );
    } catch (_) {
      await ref.read(attachmentStorageProvider).deleteFile(path);
      rethrow;
    }
  }

  static Future<void> recordAndAdd(
    BuildContext context,
    WidgetRef ref,
    String noteId,
  ) async {
    final sourcePath = await showAudioRecorder(context);
    if (sourcePath == null) return;
    final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _store(
        ref,
        noteId,
        sourcePath: sourcePath,
        fileName: fileName,
        mimeType: 'audio/mp4',
      );
    } finally {
      await deleteTemporaryRecording(sourcePath);
    }
  }

  static Future<void> pickAndAdd(WidgetRef ref, String noteId) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    await _store(
      ref,
      noteId,
      sourcePath: file.path!,
      fileName: file.name,
      mimeType: file.extension,
    );
  }

  static Future<void> pickImage(
    WidgetRef ref,
    String noteId, {
    required ImageSource source,
  }) async {
    final picker = ImagePicker();
    final lost = await picker.retrieveLostData();
    final recovered =
        lost.files != null && lost.files!.isNotEmpty ? lost.files!.first : null;
    final file = recovered ?? await picker.pickImage(source: source);
    if (file == null) return;
    await _store(
      ref,
      noteId,
      sourcePath: file.path,
      fileName: file.name,
      mimeType: 'image/${file.name.split('.').last.toLowerCase()}',
    );
  }

  static Future<void> _store(
    WidgetRef ref,
    String noteId, {
    required String sourcePath,
    required String fileName,
    required String? mimeType,
  }) async {
    final path = await ref
        .read(attachmentStorageProvider)
        .save(noteId: noteId, sourcePath: sourcePath, fileName: fileName);
    try {
      await _register(
        ref,
        noteId,
        fileName: fileName,
        path: path,
        mimeType: mimeType,
      );
    } catch (_) {
      await ref.read(attachmentStorageProvider).deleteFile(path);
      rethrow;
    }
  }

  static Future<void> _register(
    WidgetRef ref,
    String noteId, {
    required String fileName,
    required String path,
    required String? mimeType,
  }) async {
    await ref
        .read(attachmentsDaoProvider)
        .add(
          noteId: noteId,
          fileName: fileName,
          localPath: path,
          mimeType: mimeType,
          size: await attachmentFileSize(path),
        );
    await ref.read(notesDaoProvider).touch(noteId);
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return StreamBuilder<List<Attachment>>(
      stream: ref.watch(attachmentsDaoProvider).watchForNote(noteId),
      builder: (context, snapshot) {
        final attachments =
            (snapshot.data ?? const <Attachment>[])
                .where((attachment) => !isImageAttachment(attachment))
                .toList();
        if (attachments.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Attachments'),
            const SizedBox(height: Spacing.sm),
            for (final attachment in attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(
                    color: palette.surfaceSunken,
                    borderRadius: AppRadii.all(AppRadii.base),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      IconTile(
                        icon: Symbols.attach_file,
                        size: 38,
                        color: palette.textSecondary,
                        background: palette.surface,
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.titleSmall,
                            ),
                            Text(
                              _size(attachment.size),
                              style: context.mono.copyWith(
                                color: palette.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GhostIconButton(
                        icon: Symbols.close,
                        tooltip: 'Remove attachment',
                        iconSize: 19,
                        target: 38,
                        color: palette.textTertiary,
                        onPressed: () => _removeAttachment(ref, attachment),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
