/// User roles matching the `public.users` table schema.
enum UserRole {
  student,
  teacher,
  admin,
  superAdmin;

  /// Deserialize from DB string (snake_case).
  static UserRole fromString(String value) {
    return switch (value) {
      'student' => UserRole.student,
      'teacher' => UserRole.teacher,
      'admin' => UserRole.admin,
      'super_admin' => UserRole.superAdmin,
      _ => UserRole.student,
    };
  }

  /// Serialize to DB string.
  String get toDbString => switch (this) {
    UserRole.student => 'student',
    UserRole.teacher => 'teacher',
    UserRole.admin => 'admin',
    UserRole.superAdmin => 'super_admin',
  };

  /// Helper for UI checks.
  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;
}
