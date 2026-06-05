/// Shared application-wide constants.
///
/// Centralizes magic strings and literal values that are used across
/// multiple files to ensure consistency and ease of maintenance.
class AppConstants {
  AppConstants._();

  /// Default user ID used for the local-only offline-first user.
  static const String defaultUserId = 'local_user';

  /// Default user email used for the local-only offline-first user.
  static const String defaultUserEmail = 'local_user@duasaku.local';
}
