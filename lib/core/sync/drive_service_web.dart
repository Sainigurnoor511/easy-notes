import 'package:google_sign_in/google_sign_in.dart';

/// Web has no filesystem: Google Drive file sync is unsupported here.
class DriveService {
  final GoogleSignIn _signIn;

  DriveService(this._signIn);

  bool get hasSession => _signIn.currentUser != null;
}
