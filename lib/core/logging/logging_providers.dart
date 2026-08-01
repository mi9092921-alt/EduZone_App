import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data/log_queue.dart';
import 'data/log_remote_ds.dart';
import 'handlers/activity_handler.dart';
import 'handlers/analytics_handler.dart';
import 'handlers/audit_handler.dart';
import 'handlers/crash_handler.dart';
import 'infrastructure/event_bus.dart';
import 'infrastructure/event_dispatcher.dart';
import 'infrastructure/log_encryption_service.dart';
import 'infrastructure/sync_engine.dart';

part 'logging_providers.g.dart';

// ─── Core Components ─────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
EventBus eventBus(Ref ref) {
  final bus = EventBus();
  ref.onDispose(bus.dispose);
  return bus;
}

@Riverpod(keepAlive: true)
LogQueue logQueue(Ref ref) => LogQueue();

@Riverpod(keepAlive: true)
LogRemoteDataSource logRemoteDataSource(Ref ref) => LogRemoteDataSource();

@Riverpod(keepAlive: true)
LogEncryptionService logEncryptionService(Ref ref) => LogEncryptionService();

// ─── Sync Engine ─────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref) {
  final engine = SyncEngine(
    queue: ref.watch(logQueueProvider),
    remoteDs: ref.watch(logRemoteDataSourceProvider),
    eventBus: ref.watch(eventBusProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
}

// ─── Event Dispatcher (Bootstraps the pipeline) ──────────────────────────────

@Riverpod(keepAlive: true)
EventDispatcher eventDispatcher(Ref ref) {
  final queue = ref.watch(logQueueProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final encryptionService = ref.watch(logEncryptionServiceProvider);

  final dispatcher = EventDispatcher([
    AuditHandler(
      queue: queue,
      syncEngine: syncEngine,
      encryptionService: encryptionService,
    ),
    ActivityHandler(
      queue: queue,
      syncEngine: syncEngine,
    ),
    AnalyticsHandler(),
    CrashHandler(),
  ]);

  // Wire up: EventBus → Dispatcher → Handlers
  final eventBus = ref.watch(eventBusProvider);
  dispatcher.start(eventBus.stream);

  // Start the sync engine timer
  syncEngine.start();

  ref.onDispose(dispatcher.dispose);
  return dispatcher;
}
