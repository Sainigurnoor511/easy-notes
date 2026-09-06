import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/widgets/app_widgets.dart';
import 'attachment_preview_io.dart'
    if (dart.library.js_interop) 'attachment_preview_web.dart';

/// Attachments as sunken rows: thumbnail or icon tile, file name, monospaced
/// size, remove action.
class AttachmentsSection extends ConsumerWidget {
  final String noteId;

  const AttachmentsSection({super.key, required this.noteId});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = await ref.read(attachmentStorageProvider).save(
          noteId: noteId,
          sourcePath: file.path!,
          fileName: file.name,
        );
    await ref.read(attachmentsDaoProvider).add(
          noteId: noteId,
          fileName: file.name,
          localPath: path,
          mimeType: file.extension,
          size: await attachmentFileSize(path),
        );
    await ref.read(notesDaoProvider).touch(noteId);
  }

  Future<void> _remove(WidgetRef ref, Attachment a) async {
    await ref.read(attachmentStorageProvider).deleteFile(a.localPath);
    await ref.read(attachmentsDaoProvider).remove(a.id);
    await ref.read(notesDaoProvider).touch(noteId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final dao = ref.watch(attachmentsDaoProvider);

    return StreamBuilder<List<Attachment>>(
      stream: dao.watchForNote(noteId),
      builder: (context, snapshot) {
        final attachments = snapshot.data ?? const <Attachment>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachments.isNotEmpty) ...[
              const Eyebrow('Attachments'),
              const SizedBox(height: Spacing.sm),
              for (final a in attachments)
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
                        _isImage(a.mimeType)
                            ? ClipRRect(
                                borderRadius: AppRadii.all(AppRadii.handle),
                                child: attachmentThumb(a.localPath),
                              )
                            : IconTile(
                                icon: Symbols.attach_file,
                                size: 34,
                                color: palette.textSecondary,
                                background: palette.surface,
                              ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.titleSmall,
                              ),
                              Text(
                                _size(a.size),
                                style: context.mono
                                    .copyWith(color: palette.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        GhostIconButton(
                          icon: Symbols.close,
                          tooltip: 'Remove attachment',
                          iconSize: 16,
                          target: 30,
                          color: palette.textTertiary,
                          onPressed: () => _remove(ref, a),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: Spacing.xs),
            ],
            OutlinedButton.icon(
              onPressed: () => _add(context, ref),
              icon: const Icon(Symbols.attach_file, size: 17),
              label: const Text('Add attachment'),
            ),
          ],
        );
      },
    );
  }

  bool _isImage(String? mime) =>
      mime != null &&
      (mime.toLowerCase().startsWith('img') ||
          const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic']
              .contains(mime.toLowerCase()));

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
