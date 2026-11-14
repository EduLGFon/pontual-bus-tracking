// Typed failures and Result helpers. Production code returns Result
// instead of throwing across module boundaries; user-facing messages come
// from strings_pt.dart at the presentation layer. See ARCHITECTURE.md 14.2.

/// Sealed family of application failures.
sealed class AppFailure {
  /// Creates a failure with a developer-facing [message].
  const AppFailure(this.message);

  /// Developer-facing description. Never shown to users directly.
  final String message;
}

/// Network could not be reached or timed out.
class NetworkFailure extends AppFailure {
  /// Creates a network failure.
  const NetworkFailure(super.message);
}

/// The server rejected the request with a known error code.
class ServerFailure extends AppFailure {
  /// Creates a server failure with the API error [code].
  const ServerFailure(super.message, this.code);

  /// API error code such as auth, gone, or maint.
  final String code;
}

/// Local storage or cache failure.
class StorageFailure extends AppFailure {
  /// Creates a storage failure.
  const StorageFailure(super.message);
}

/// Location services or permission failure.
class LocationFailure extends AppFailure {
  /// Creates a location failure.
  const LocationFailure(super.message);
}

/// Result of an operation that can fail with an [AppFailure].
sealed class Result<T> {
  /// Creates a result.
  const Result();
}

/// Successful result carrying [value].
class Ok<T> extends Result<T> {
  /// Creates a success.
  const Ok(this.value);

  /// Success value.
  final T value;
}

/// Failed result carrying [failure].
class Err<T> extends Result<T> {
  /// Creates a failure result.
  const Err(this.failure);

  /// What went wrong.
  final AppFailure failure;
}
