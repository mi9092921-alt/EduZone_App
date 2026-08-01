

import 'app_event.dart';

/// A single entry in the in-memory log queue, ready for Supabase sync.
class LogEntry {
  final String idempotencyKey;
  final String eventType;
  final String category;
  final String? userId;
  final String? tenantId;
  final String? deviceId;
  final Map<String, dynamic> details;
  final String riskLevel;
  final DateTime createdAt;
  final bool isEncrypted;

  /// Tracks first failure time for time-based retry window.
  DateTime? firstFailedAt;

  LogEntry({
    required this.idempotencyKey,
    required this.eventType,
    required this.category,
    this.userId,
    this.tenantId,
    this.deviceId,
    required this.details,
    this.riskLevel = 'low',
    required this.createdAt,
    this.isEncrypted = false,
    this.firstFailedAt,
  });

  /// Create a LogEntry from an [AppEvent].
  factory LogEntry.fromEvent(AppEvent event, {bool encrypted = false, Map<String, dynamic>? encryptedDetails}) {
    return LogEntry(
      idempotencyKey: event.idempotencyKey,
      eventType: event.activityType,
      category: event.category.name,
      userId: event.userId,
      tenantId: event.tenantId,
      deviceId: event.deviceId,
      details: encryptedDetails ?? event.details,
      riskLevel: event.riskLevel.name,
      createdAt: event.timestamp,
      isEncrypted: encrypted,
    );
  }

  /// Has this entry been failing for longer than [maxAge]?
  bool isExpired(Duration maxAge) {
    if (firstFailedAt == null) return false;
    return DateTime.now().difference(firstFailedAt!) > maxAge;
  }

  /// Convert to Supabase-compatible map for `activity_log_queue` insert.
  Map<String, dynamic> toSupabaseMap() {
    return {
      'activity_type': eventType,
      'user_id': userId, // allow null for anonymous events
      'tenant_id': tenantId ?? '00000000-0000-0000-0000-000000000001', // Fallback to System Tenant
      'details': details, // Send Map directly for JSONB
      'device_id': deviceId,
      'risk_level': riskLevel,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
