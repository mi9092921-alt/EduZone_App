/// Central timeout budgets for network-bound calls (Supabase
/// Postgrest/RPC/Auth/Edge Function requests) made from data sources.
///
/// Before this file existed, exactly one call site in the whole app
/// (`CoursesRemoteDataSourceImpl.getCourseOutline`) applied a client-side
/// timeout; every other Postgrest/RPC/Edge-Function call across courses,
/// home, notifications, todo, profile and video_player had no bound at
/// all, so a stalled connection meant the awaiting `Future` never
/// completed and the caller's loading state hung indefinitely. See
/// Section 13 ("Networking Reliability") of the project instructions.
///
/// These values are deliberately centralized instead of duplicated as
/// magic numbers per call site so the whole app's network budget can be
/// tuned in one place once real production latency data exists (see
/// P8.0 Performance Baseline in the performance roadmap) — the initial
/// values below are conservative defaults, not measured baselines.
class NetworkConfig {
  NetworkConfig._();

  /// Default budget for a single idempotent read (a `select`/`rpc` that
  /// only fetches data). Generous enough for a slow mobile connection,
  /// tight enough that a stalled request doesn't hang a loading spinner
  /// indefinitely.
  static const Duration readTimeout = Duration(seconds: 15);

  /// Budget for a write (`insert`/`update`/`upsert`/mutating `rpc`).
  /// Slightly larger than [readTimeout] because writes that touch
  /// triggers/RLS policies on the server can legitimately take a little
  /// longer, and because timing a write out client-side while it may
  /// still commit server-side is a real correctness risk we'd rather
  /// avoid triggering unnecessarily.
  static const Duration writeTimeout = Duration(seconds: 20);

  /// Budget for calls known to be heavier (Edge Functions doing external
  /// work, e.g. Player4's `video-info` function).
  static const Duration heavyTimeout = Duration(seconds: 25);

  /// Max attempts (including the first) for [readTimeout]-class retried
  /// calls. Only ever applied to reads -- see `NetworkRetry`.
  static const int maxReadAttempts = 3;

  /// Base delay for exponential backoff between retried read attempts.
  static const Duration retryBaseDelay = Duration(milliseconds: 400);
}
