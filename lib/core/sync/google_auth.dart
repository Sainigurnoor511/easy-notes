import 'package:google_sign_in/google_sign_in.dart';

/// Narrowest usable Drive scope: access only to files created by this app.
const List<String> kDriveScopes = [
  'https://www.googleapis.com/auth/drive.file',
];

/// GoogleSignIn shared by auth + sync. Works on all platforms.
final GoogleSignIn googleSignInInstance = GoogleSignIn(scopes: kDriveScopes);
