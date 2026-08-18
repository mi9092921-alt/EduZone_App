import 'dart:async';

import '../error/exceptions.dart';
import 'network_config.dart';
import 'network_exception_mapper.dart';

/// Single choke point for every network-bound datasource call: applies a
/// client-side timeout, classifies whatever comes out of it into the
/// typed [AppException] taxonomy via [NetworkExceptionMapper], and
/// optionally retries with exponential backoff -- but *only* for calls
/// the caller has explicitly marked as an idempotent read.
///
/// This exists because, before it did, individual datasources each
/// implemented (or, far more often, omitted) their own subset of:
/// timeout, connectivity/DNS-failure detection, malformed-response
/// handling, and retry -- see Section 13 ("Networking Reliability") of
/// the project instructions, which requires all of these consistently
/// across every network operation. Centralizing them here means every
/// call site gets the same behavior by construction instead of by
/// developer discipline, matching the same reasoning already applied to
/// the design-token/accessibility guards elsewhere in this codebase.
///
/// Usage:
/// ```dart
/// // Idempotent read -- safe to retry on transient failures.
/// final rows = await NetworkGuard.read(() => _client.from('courses').select());
///
/// // Write/mutation -- timed out and error-mapped, but never
/// // auto-retried (the project instructions explicitly forbid blindly
/// // retrying non-idempotent operations; even for upserts that *are*
/// // idempotent server-side, auto-retrying a write from this generic
/// // helper risks retry storms on hot paths like progress sync).
/// await NetworkGuard.write(() => _client.from('todos').insert(row));
/// ```
class NetworkGuard {
  NetworkGuard._();

  /// Runs an idempotent read [call]. Applies [timeout] (default
  /// [NetworkConfig.readTimeout]) and retries up to [maxAttempts] times
  /// with exponential backoff, but only when the failure classifies as
  /// transient/connectivity-level (see
  /// [NetworkExceptionMapper.isRetryable]) -- a business/validation
  /// error (invalid input, RLS denial, not-found, rate limit, malformed
  /// response) is thrown immediately on the first attempt.
  static Future<T> read<T>(
    Future<T> Function() call, {
    Duration timeout = NetworkConfig.readTimeout,
    int maxAttempts = NetworkConfig.maxReadAttempts,
    Duration retryBaseDelay = NetworkConfig.retryBaseDelay,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await call().timeout(timeout);
      } catch (error) {
        final mapped = NetworkExceptionMapper.map(error);
        final canRetry =
            NetworkExceptionMapper.isRetryable(mapped) && attempt < maxAttempts;
        if (!canRetry) throw mapped;

        // Exponential backoff: baseDelay * 2^(attempt-1), e.g. with the
        // 400ms default: 400ms, 800ms -- bounded by maxAttempts so this
        // can never spin indefinitely.
        final delay = retryBaseDelay * (1 << (attempt - 1));
        await Future<void>.delayed(delay);
      }
    }
  }

  /// Runs a write/mutation [call]. Applies [timeout] (default
  /// [NetworkConfig.writeTimeout]) and maps whatever comes out of it to
  /// the typed exception taxonomy, but never retries -- a write is not
  /// automatically safe to repeat just because it looked transient
  /// client-side (the request may have reached the server and applied
  /// before the client-side timeout fired).
  static Future<T> write<T>(
    Future<T> Function() call, {
    Duration timeout = NetworkConfig.writeTimeout,
  }) async {
    try {
      return await call().timeout(timeout);
    } catch (error) {
      throw NetworkExceptionMapper.map(error);
    }
  }
}
