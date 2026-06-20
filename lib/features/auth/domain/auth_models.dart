class User {
  final String id;
  final String email;

  User({required this.id, required this.email});
}

class Session {
  final User user;
  final String accessToken;

  Session({required this.user, required this.accessToken});
}

class AuthResponse {
  final Session? session;
  final User? user;

  AuthResponse({this.session, this.user});
}

class AuthState {
  final Session? session;

  AuthState({this.session});

  bool get isAuthenticated => session != null;
}
