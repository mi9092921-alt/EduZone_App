/// Structured result returned by LogoutOrchestrator.execute().
/// Used for observability, logging, and debugging — not for UI decisions.
class LogoutResult {
  final bool success;
  final String logoutFlow;       // 'manual' | 'forced' | 'token_expired'
  final List<String> failedSteps;
  final int durationMs;

  const LogoutResult({
    required this.success,
    required this.logoutFlow,
    required this.failedSteps,
    required this.durationMs,
  });

  /// Serializes to structured JSON for Sentry / logging.
  Map<String, dynamic> toLog() => {
        'event': 'logout',
        'flow': logoutFlow,
        'success': success,
        'steps_completed': 7 - failedSteps.length,
        'failed_steps': failedSteps,
        'duration_ms': durationMs,
      };
}
