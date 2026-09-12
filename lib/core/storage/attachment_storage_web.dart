/// Web has no local filesystem: attachments are unsupported on this platform.
class AttachmentStorage {
  Future<String> saveBytes({
    required String noteId,
    required List<int> bytes,
    required String fileName,
  }) async {
    throw UnsupportedError('Attachments are not supported on web.');
  }

  Future<String> save({
    required String noteId,
    required String sourcePath,
    required String fileName,
  }) async {
    throw UnsupportedError('Attachments are not supported on web.');
  }

  Future<void> deleteFile(String localPath) async {}

  Future<void> deleteNoteFiles(String noteId) async {}

  Future<int> totalSize() async => 0;
}
