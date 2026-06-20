/// A sealed class representing application-level errors.
///
/// Used with [Result] to provide type-safe error handling without exceptions
/// for expected failure cases (not found, database errors, validation errors).
///
/// Example usage:
/// ```dart
/// final result = await repository.getItem(id);
/// switch (result) {
///   case Success(:final value):
///     // handle success
///   case Failure(:final error):
///     switch (error) {
///       case NotFoundError():
///         // handle not found
///       case DatabaseError():
///         // handle database error
///       case ValidationError():
///         // handle validation error
///       case UnknownError():
///         // handle unknown error
///     }
/// }
/// ```
sealed class AppError {
  const AppError(this.message, {this.stackTrace});

  @override
  String toString() => message;


  /// Human-readable error message.
  final String message;

  /// Optional stack trace for debugging.
  final StackTrace? stackTrace;

  /// Creates a [NotFoundError] for when a requested resource does not exist.
  factory AppError.notFound(String message, {StackTrace? stackTrace}) =
      NotFoundError;

  /// Creates a [DatabaseError] for database operation failures.
  factory AppError.database(String message, {StackTrace? stackTrace}) =
      DatabaseError;

  /// Creates a [ValidationError] for invalid input or constraint violations.
  factory AppError.validation(String message, {StackTrace? stackTrace}) =
      ValidationError;

  /// Creates an [UnknownError] for unexpected or unclassified failures.
  factory AppError.unknown(String message, {StackTrace? stackTrace}) =
      UnknownError;
}

/// Error indicating a requested resource was not found.
final class NotFoundError extends AppError {
  const NotFoundError(super.message, {super.stackTrace});
}

/// Error indicating a database operation failure.
final class DatabaseError extends AppError {
  const DatabaseError(super.message, {super.stackTrace});
}

/// Error indicating invalid input or a constraint violation.
final class ValidationError extends AppError {
  const ValidationError(super.message, {super.stackTrace});
}

/// Error indicating an unexpected or unclassified failure.
final class UnknownError extends AppError {
  const UnknownError(super.message, {super.stackTrace});
}
