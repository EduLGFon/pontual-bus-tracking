// Typed failures. Mirrors app/lib/core/errors/failures.dart.
export class Failure extends Error {
  constructor(message: string) {
    super(message);
    this.name = "Failure";
  }
}
export class NetworkFailure extends Failure {
  constructor(message: string) {
    super(message);
    this.name = "NetworkFailure";
  }
}
export class ServerFailure extends Failure {
  constructor(message: string, public readonly code: string) {
    super(message);
    this.name = "ServerFailure";
  }
}
export class ValidationFailure extends Failure {
  constructor(message: string) {
    super(message);
    this.name = "ValidationFailure";
  }
}
