import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

Future<AppDatabase> openPlatformDatabase() async {
  return AppDatabase(driftDatabase(name: 'easy_notes'));
}
