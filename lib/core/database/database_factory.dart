import 'database_factory_io.dart'
    if (dart.library.js_interop) 'database_factory_web.dart';

import 'app_database.dart';

/// Opens the platform-appropriate database. IO and web use different
/// executors (native sqlite vs WebAssembly sqlite).
Future<AppDatabase> openAppDatabase() {
  return openPlatformDatabase();
}
