/// A Google account profile. No passwords or tokens are stored in the app.
class AuthUser {
  final String name;
  final String email;
  final String? photoUrl;

  const AuthUser({required this.name, required this.email, this.photoUrl});

  Map<String, String> toPrefs() => {
    'name': name,
    'email': email,
    'photoUrl': photoUrl ?? '',
  };

  static AuthUser fromPrefs(Map<String, String> map) => AuthUser(
    name: map['name'] ?? '',
    email: map['email'] ?? '',
    photoUrl: map['photoUrl'] == '' ? null : map['photoUrl'],
  );
}

enum AuthStatus { signedOut, signedIn, offline }

class AuthState {
  final AuthStatus status;
  final AuthUser? user;

  const AuthState({required this.status, this.user});

  const AuthState.signedOut() : this(status: AuthStatus.signedOut);
}
