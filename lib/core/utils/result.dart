/// A sealed class representing the result of an operation that can either
/// succeed with a value of type [T] or fail with an error of type [E].
///
/// Use pattern matching to handle both cases:
/// ```dart
/// final result = someOperation();
/// switch (result) {
///   case Success(:final value):
///     // handle success
///   case Failure(:final error):
///     // handle failure
/// }
/// ```
sealed class Result<T, E> {
  const Result();
}

/// Represents a successful result containing a [value] of type [T].
final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

/// Represents a failed result containing an [error] of type [E].
final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}
