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
      // Fallback: write unencrypted if encryption fails
      debugPrint(
        '[AuditHandler] Encryption failed, writing unencrypted: '
        '${e.runtimeType}',
      );
      final entry = LogEntry.fromEvent(event);
      _queue.add(entry);
      _syncEngine.onEntryAdded();
    }
  }
}
