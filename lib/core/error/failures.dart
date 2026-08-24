import 'package:equatable/equatable.dart';

import '../network/network_exception_mapper.dart';
import 'exceptions.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// No internet connection -- mirrors [NoInternetException]. Kept distinct
/// from [ServerFailure] so a repository catching a raw
/// [NoInternetException] (thrown by the datasource layer, e.g. via
/// `NetworkExceptionMapper`) doesn't collapse it back down to a generic
/// server-error string before it reaches the provider/UI layer. Without
/// this, "no internet" and "the server rejected the request" were
/// indistinguishable by the time an `Either<Failure, T>` result reached
/// a Riverpod provider (see Section 13 of the project instructions).
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']); // check-ignore
}

/// A network-bound call did not complete within its client-side timeout
/// budget -- mirrors [RequestTimeoutException]. See [NetworkFailure] for
/// why this is a distinct type instead of being folded into
/// [ServerFailure].
class RequestTimeoutFailure extends Failure {
  const RequestTimeoutFailure([super.message = 'Request timed out']); // check-ignore
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class AlreadyDownloadedFailure extends Failure {
  const AlreadyDownloadedFailure([super.message = 'Lesson already downloaded']); // check-ignore
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

/// A lifecycle action (pause/resume/cancel/...) was requested against a
/// resource that is not currently in a state the action is legal for --
/// e.g. resuming a download that is already `completed`, or pausing one
/// that already `failed`. Kept distinct from [UnknownFailure] so callers
/// (providers/UI) can tell "your request was well-formed but doesn't apply
/// right now" apart from "something actually went wrong", and so a denial
/// here is never silently swallowed into a reported success. See
/// download-subsystem-production-hardening-plan.md Phase 3 (illegal
/// download-status transitions) for the motivating case.
class InvalidDownloadStateFailure extends Failure {
  const InvalidDownloadStateFailure(super.message);
}

/// Reconstructs the typed [AppException] a [Failure] was derived from, so
/// call sites that must re-throw across an `Either<Failure, T>` boundary
/// (Riverpod providers built on top of a repository) don't have to fall
/// back to an untyped `Exception(failure.message)` -- which would
/// silently defeat every classification `NetworkExceptionMapper` and
/// `ErrorHandler` do downstream (see courses/home providers).
///
/// This is a best-effort reconstruction: [ServerFailure]/[CacheFailure]/
/// etc. only ever carried a message string to begin with, so the
/// resulting [ServerException] necessarily loses the original Postgrest
/// error code. That's an accepted, pre-existing limitation of the
/// `Either<Failure, T>` pattern itself (a repository-boundary widening),
/// not something introduced here -- the alternative (this file depending
/// on every feature's own domain-level failure conventions) would be a
/// far larger, riskier change than the "smallest safe diff" this pass is
/// scoped to.
extension FailureToAppException on Failure {
  AppException toAppException() {
    final self = this;
    if (self is NetworkFailure) return const NoInternetException();
    if (self is RequestTimeoutFailure) return const RequestTimeoutException();
    return ServerException(message); // check-ignore
  }
}

/// Classifies a raw caught error into the right [Failure] subtype,
/// preserving the [NoInternetException]/[RequestTimeoutException]
/// distinction that `NetworkExceptionMapper` establishes instead of
/// collapsing everything to [ServerFailure] the moment it crosses into
/// the repository's `Either` boundary.
///
/// Delegates to [NetworkExceptionMapper.map] for anything not already an
/// [AppException] -- so a raw `PostgrestException`/`SocketException`
/// thrown directly by a data source (as several repository unit tests
/// deliberately exercise) is classified exactly the same way here as it
/// would be inside a `NetworkGuard`-wrapped data source call, instead of
/// this file needing its own separate copy of that classification logic.
Failure failureFromError(Object error) {
  final classified = error is AppException
      ? error
      : NetworkExceptionMapper.map(error);
  if (classified is NoInternetException) {
    return NetworkFailure(classified.message);
  }
  if (classified is RequestTimeoutException) {
    return RequestTimeoutFailure(classified.message);
  }
  return ServerFailure(classified.message);
}
