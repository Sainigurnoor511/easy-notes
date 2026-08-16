import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import 'attachment_preview_io.dart'
    if (dart.library.js_interop) 'attachment_preview_web.dart';

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
    final dao = ref.watch(attachmentsDaoProvider);
    return StreamBuilder<List<Attachment>>(
      stream: dao.watchForNote(noteId),
      builder: (context, snapshot) {
        final attachments = snapshot.data ?? const <Attachment>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: _isImage(a.mimeType)
                    ? attachmentThumb(a.localPath)
                    : const Icon(Icons.attach_file),
                title: Text(a.fileName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_size(a.size)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove attachment',
                  onPressed: () => _remove(ref, a),
                ),
              ),
            TextButton.icon(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.attach_file),
              label: const Text('Add attachment'),
            ),
          ],
        );
      },
    );
  }

  bool _isImage(String? mime) =>
      mime != null && (mime.toLowerCase().startsWith('img') ||
          const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic']
              .contains(mime.toLowerCase()));

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
