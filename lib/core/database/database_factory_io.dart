import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

Future<AppDatabase> openPlatformDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'easy_notes.sqlite'));
  await file.parent.create(recursive: true);
  return AppDatabase(NativeDatabase.createInBackground(file));
}
