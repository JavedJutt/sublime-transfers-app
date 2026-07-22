/// A user's role. Mirrors the `user_role` Postgres enum. A user is exactly one.
enum UserRole {
  admin,
  driver;

  static UserRole fromWire(String value) => switch (value) {
        'admin' => UserRole.admin,
        'driver' => UserRole.driver,
        _ => throw ArgumentError('Unknown user_role: $value'),
      };

  String get wire => name;

  bool get isAdmin => this == UserRole.admin;
  bool get isDriver => this == UserRole.driver;
}
