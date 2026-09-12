import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// http client that injects a fresh bearer token per request.
class _AuthenticatedClient extends http.BaseClient {
  final GoogleSignIn _signIn;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._signIn);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final user = _signIn.currentUser;
    if (user == null) throw StateError('Not signed in');
    final auth = await user.authentication;
    request.headers['Authorization'] = 'Bearer ${auth.accessToken}';
    return _inner.send(request);
  }
}

class DriveService {
  final GoogleSignIn _signIn;
  drive.DriveApi? _api;

  DriveService(this._signIn);

  Future<drive.DriveApi> get api async {
    _api ??= drive.DriveApi(_AuthenticatedClient(_signIn));
    return _api!;
  }

  bool get hasSession => _signIn.currentUser != null;

  /// Finds or creates the app folder in My Drive.
  Future<String> ensureFolder(String name) async {
    final a = await api;
    final existing = await findFileId(
      parent: 'root',
      name: name,
      mimeType: 'application/vnd.google-apps.folder',
    );
    if (existing != null) return existing;
    final created = await a.files.create(
      drive.File(name: name, mimeType: 'application/vnd.google-apps.folder'),
    );
    return created.id!;
  }

  /// Finds or creates a sub-folder inside [parentId].
  Future<String> ensureFolderIn(String name, String parentId) async {
    final a = await api;
    final existing = await findFileId(
      parent: parentId,
      name: name,
      mimeType: 'application/vnd.google-apps.folder',
    );
    if (existing != null) return existing;
    final created = await a.files.create(
      drive.File(
        name: name,
        mimeType: 'application/vnd.google-apps.folder',
        parents: [parentId],
      ),
    );
    return created.id!;
  }

  Future<String?> findFileId({
    required String parent,
    required String name,
    String? mimeType,
  }) async {
    final a = await api;
    final q =
        "'$parent' in parents and name = '$name'${mimeType == null ? '' : " and mimeType = '$mimeType'"} and trashed = false";
    final res = await a.files.list(
      q: q,
      spaces: 'drive',
      pageSize: 1,
      $fields: 'files(id)',
    );
    if (res.files == null || res.files!.isEmpty) return null;
    return res.files!.first.id;
  }

  Future<void> uploadFile({
    required io.File file,
    required String name,
    required String parentId,
    String? mimeType,
  }) async {
    final a = await api;
    final bytes = await file.readAsBytes();
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: mimeType ?? 'application/octet-stream',
    );
    final existingId = await findFileId(parent: parentId, name: name);
    if (existingId != null) {
      await a.files.update(drive.File(), existingId, uploadMedia: media);
    } else {
      await a.files.create(
        drive.File(name: name, parents: [parentId]),
        uploadMedia: media,
      );
    }
  }

  Future<io.File> downloadFile({
    required String fileId,
    required io.File dest,
  }) async {
    final a = await api;
    final res =
        await a.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final Uint8List bytes = Uint8List.fromList(
      await res.stream.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      ),
    );
    await dest.writeAsBytes(bytes);
    return dest;
  }

  Future<DateTime?> fileModifiedAt(String fileId) async {
    final a = await api;
    final f = await a.files.get(fileId) as drive.File;
    return f.modifiedTime;
  }

  Future<void> deleteFile(String fileId) async {
    final a = await api;
    await a.files.delete(fileId);
  }

  Future<Map<String, String>> listFilesInFolder(String parentId) async {
    final a = await api;
    final res = await a.files.list(
      q: "'$parentId' in parents and trashed = false",
      $fields: 'files(id, name)',
      pageSize: 1000,
    );
    final map = <String, String>{};
    for (final f in res.files ?? const <drive.File>[]) {
      map[f.name ?? ''] = f.id!;
    }
    return map;
  }

  /// metadata.json contents (or null when the file does not exist yet).
  Future<Map<String, dynamic>?> readMetadata({
    required String folderId,
    required String fileName,
  }) async {
    final a = await api;
    final id = await findFileId(parent: folderId, name: fileName);
    if (id == null) return null;
    final res =
        await a.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia)
            as drive.Media;
    final bytes = Uint8List.fromList(
      await res.stream.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      ),
    );
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<void> writeMetadata({
    required String folderId,
    required String fileName,
    required Map<String, dynamic> data,
  }) async {
    final bytes = utf8.encode(jsonEncode(data));
    final tempDir = await getTemporaryDirectory();
    final temp = io.File(p.join(tempDir.path, 'sync_metadata.json'));
    await temp.writeAsBytes(bytes);
    await uploadFile(
      file: temp,
      name: fileName,
      parentId: folderId,
      mimeType: 'application/json',
    );
    await temp.delete();
  }
}
