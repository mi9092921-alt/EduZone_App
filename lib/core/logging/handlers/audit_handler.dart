import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/log_queue.dart';
import '../domain/app_event.dart';
import '../domain/event_metadata.dart';
import '../infrastructure/log_encryption_service.dart';
import '../infrastructure/sync_engine.dart';
import 'event_handler.dart';

/// Handles sensitive auth events and high-risk system events.
///
/// Encrypts the `details` JSON with AES-256-GCM before writing
/// to [LogQueue]. Tags entries with the appropriate risk level.
class AuditHandler extends EventHandler {
  final LogQueue _queue;
  final SyncEngine _syncEngine;
  final LogEncryptionService _encryptionService;

  AuditHandler({
    required LogQueue queue,
    required SyncEngine syncEngine,
    required LogEncryptionService encryptionService,
  })  : _queue = queue,
        _syncEngine = syncEngine,
        _encryptionService = encryptionService;

  @override
  bool shouldHandle(AppEvent event) {
    // Handle all auth events + any high/critical risk events
    return event.category == EventCategory.auth ||
        event.riskLevel == EventRiskLevel.high ||
        event.riskLevel == EventRiskLevel.critical;
  }

  @override
  void handle(AppEvent event) {
    _handleAsync(event);
  }

  Future<void> _handleAsync(AppEvent event) async {
    try {
      final detailsJson = jsonEncode(event.details);
      final encryptedDetails = await _encryptionService.encrypt(detailsJson);

      final entry = LogEntry.fromEvent(
        event,
        encrypted: true,
        encryptedDetails: {'encrypted': encryptedDetails},
      );

      _queue.add(entry);
      _syncEngine.onEntryAdded();
    } catch (e) {
      // Fail-closed (Section 15 / Section 11 threat model): this handler
      // only ever receives auth-category events or high/critical-risk
      // events (see [shouldHandle]) -- e.g. AuthAccessDeniedEvent.reason,
      // AuthDeviceBindEvent.bindDeviceId, offline-playback-denial
      // reasons. If AES-GCM encryption fails we must NOT fall back to
      // shipping that `details` payload to Supabase in plaintext; that
      // would silently defeat the entire reason this handler encrypts
      // in the first place. Instead we ship a redacted placeholder so
      // the *fact* that a security-relevant event occurred (type,
      // category, risk, user/device/tenant ids, timestamp) is still
      // observable for ops, without ever leaking the sensitive
      // `details` content in the clear. `isEncrypted` is left at its
      // default `false` so this is never mistaken for a real
      // ciphertext entry downstream.
      debugPrint(
        '[AuditHandler] Encryption failed (${e.runtimeType}); '
        'shipping redacted entry instead of plaintext.',
      );
      final redactedEntry = LogEntry.fromEvent(
        event,
        encryptedDetails: const {
          '_redacted': true,
          '_reason': 'encryption_unavailable',
        },
      );
      _queue.add(redactedEntry);
      _syncEngine.onEntryAdded();
    }
  }
}
