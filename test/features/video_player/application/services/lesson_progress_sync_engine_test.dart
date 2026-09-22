import 'dart:convert';

import 'package:app/core/error/failures.dart';
import 'package:app/features/video_player/application/services/lesson_progress_outbox_store.dart';
import 'package:app/features/video_player/application/services/lesson_progress_sync_engine.dart';
import 'package:app/features/video_player/domain/entities/lesson_progress_sync_item.dart';
import 'package:app/features/video_player/domain/repositories/video_player_repository.dart';
import 'package:app/features/video_player/domain/usecases/sync_lesson_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockVideoPlayerRepository extends Mock implements VideoPlayerRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockVideoPlayerRepository repository;
  late LessonProgressSyncEngine engine;

  setUpAll(() {
    registerFallbackValue(<LessonProgressSyncItem>[]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockVideoPlayerRepository();
    engine = LessonProgressSyncEngine(
      syncLessonProgress: SyncLessonProgress(repository),
      outboxStore: LessonProgressOutboxStore(),
      flushInterval: const Duration(milliseconds: 20),
      maxBatchSize: 3,
    );

    when(
      () => repository.syncProgressBatch(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() async {
    await engine.dispose();
  });

  test('merges multiple progress updates for the same lesson', () async {
    engine
      ..enqueue(
        const LessonProgressSyncItem(
          courseId: 'c1',
          lessonId: 'l1',
          completed: false,
          progressPct: 10,
          watchTimeSec: 5,
        ),
      )
      ..enqueue(
        const LessonProgressSyncItem(
          courseId: 'c1',
          lessonId: 'l1',
          completed: false,
          progressPct: 40,
          watchTimeSec: 20,
        ),
        flushNow: true,
      );

    await Future<void>.delayed(Duration.zero);

    verify(
      () => repository.syncProgressBatch(
        any(
          that: predicate<List<LessonProgressSyncItem>>((items) {
            return items.length == 1 &&
                items.single.courseId == 'c1' &&
                items.single.lessonId == 'l1' &&
                items.single.progressPct == 40 &&
                items.single.watchTimeSec == 20;
          }),
        ),
      ),
    ).called(1);
  });

  test('ignores new progress after disposal', () async {
    await engine.dispose();

    engine.enqueue(
      const LessonProgressSyncItem(
        courseId: 'c1',
        lessonId: 'l1',
        completed: false,
        progressPct: 90,
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(engine.pendingCount, 0);
    verifyNever(() => repository.syncProgressBatch(any()));
  });

  test('flushes and seals the queue at a session boundary', () async {
    engine.enqueue(
      const LessonProgressSyncItem(
        courseId: 'old-course',
        lessonId: 'old-lesson',
        completed: false,
        progressPct: 45,
      ),
    );

    await engine.closeSession(flushPending: true);

    verify(
      () => repository.syncProgressBatch(
        any(
          that: predicate<List<LessonProgressSyncItem>>(
            (items) => items.single.courseId == 'old-course',
          ),
        ),
      ),
    ).called(1);

    engine.openSession();
    engine.enqueue(
      const LessonProgressSyncItem(
        courseId: 'new-course',
        lessonId: 'new-lesson',
        completed: false,
        progressPct: 10,
      ),
      flushNow: true,
    );
    await Future<void>.delayed(Duration.zero);

    verify(
      () => repository.syncProgressBatch(
        any(
          that: predicate<List<LessonProgressSyncItem>>(
            (items) => items.single.courseId == 'new-course',
          ),
        ),
      ),
    ).called(1);
  });

  test('requeues the batch when sync fails', () async {
    when(
      () => repository.syncProgressBatch(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('offline')));

    engine.enqueue(
      const LessonProgressSyncItem(
        courseId: 'c1',
        lessonId: 'l1',
        completed: false,
        progressPct: 10,
      ),
      flushNow: true,
    );

    await Future<void>.delayed(Duration.zero);

    expect(engine.pendingCount, 1);
  });

  test(
    'closeSession discards a failed/retry-queued item instead of leaving '
    "it to retry under a future account's session (STATE-003 regression)",
    () async {
      // Account A's flush fails (e.g. offline right as they log out) and is
      // left queued for retry, exactly like "requeues the batch when sync
      // fails" above.
      when(
        () => repository.syncProgressBatch(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('offline')));

      engine.enqueue(
        const LessonProgressSyncItem(
          courseId: 'account-a-course',
          lessonId: 'account-a-lesson',
          completed: false,
          progressPct: 10,
        ),
        flushNow: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(engine.pendingCount, 1);

      // Logout closes the session. This must discard the failed item
      // rather than leave it queued for the retry timer -- otherwise, once
      // a *different* account opens a new session on this device, the
      // eventual retry would call syncProgressBatch() with account A's
      // course/lesson data while the ambient Supabase session belongs to
      // account B (video_player_remote_ds.dart reads currentUser.id at
      // flush time, not enqueue time), silently attributing account A's
      // watch progress to account B.
      await engine.closeSession();
      expect(engine.pendingCount, 0);

      // A different account's session opens and the retry timer's original
      // window elapses. The stale item must never have been flushed.
      clearInteractions(repository);
      when(
        () => repository.syncProgressBatch(any()),
      ).thenAnswer((_) async => const Right(null));
      engine.openSession();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      verifyNever(
        () => repository.syncProgressBatch(
          any(
            that: predicate<List<LessonProgressSyncItem>>(
              (items) => items.any((i) => i.courseId == 'account-a-course'),
            ),
          ),
        ),
      );
    },
  );

  group('retry budget (Phase 8: no unbounded failure/retry loop)', () {
    test(
      'stops timer-driven retries after maxConsecutiveFailures straight failures',
      () async {
        final bounded = LessonProgressSyncEngine(
          syncLessonProgress: SyncLessonProgress(repository),
          outboxStore: LessonProgressOutboxStore(),
          flushInterval: const Duration(milliseconds: 10),
          maxConsecutiveFailures: 2,
        );
        when(
          () => repository.syncProgressBatch(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('denied')));

        bounded.enqueue(
          const LessonProgressSyncItem(
            courseId: 'c1',
            lessonId: 'l1',
            completed: false,
            progressPct: 10,
          ),
          flushNow: true,
        );
        // Initial flush + one budgeted retry (the budget counts the
        // initial attempt as the first consecutive failure).
        await Future<void>.delayed(const Duration(milliseconds: 60));
        final attempts = verify(
          () => repository.syncProgressBatch(any()),
        ).callCount;
        expect(attempts, 2);

        // Well past any backoff interval the engine would use — no further
        // attempt may fire: the idle retry loop has a terminal state.
        // (verifyNever counts only calls since the previous verify.)
        await Future<void>.delayed(const Duration(milliseconds: 200));
        verifyNever(() => repository.syncProgressBatch(any()));

        await bounded.dispose();
      },
    );

    test(
      'an event-driven flush still attempts after the budget is exhausted '
      '(recovery path)',
      () async {
        final bounded = LessonProgressSyncEngine(
          syncLessonProgress: SyncLessonProgress(repository),
          outboxStore: LessonProgressOutboxStore(),
          flushInterval: const Duration(milliseconds: 10),
          maxConsecutiveFailures: 1,
        );
        when(
          () => repository.syncProgressBatch(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('denied')));

        bounded.enqueue(
          const LessonProgressSyncItem(
            courseId: 'c1',
            lessonId: 'l1',
            completed: false,
            progressPct: 10,
          ),
          flushNow: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        // Budget exhausted; a fresh enqueue forced by a completed lesson
        // must still attempt once (event-driven, not timer-driven).
        clearInteractions(repository);
        when(
          () => repository.syncProgressBatch(any()),
        ).thenAnswer((_) async => const Right(null));
        bounded.enqueue(
          const LessonProgressSyncItem(
            courseId: 'c1',
            lessonId: 'l1',
            completed: true,
            progressPct: 100,
          ),
          flushNow: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        verify(() => repository.syncProgressBatch(any())).called(1);
        expect(bounded.pendingCount, 0);

        await bounded.dispose();
      },
    );

    test(
      'a successful flush resets the consecutive-failure budget',
      () async {
        final bounded = LessonProgressSyncEngine(
          syncLessonProgress: SyncLessonProgress(repository),
          outboxStore: LessonProgressOutboxStore(),
          flushInterval: const Duration(milliseconds: 10),
          maxConsecutiveFailures: 2,
        );
        // Fail twice (budget exhausted), succeed once (reset), then the
        // next failure cycle must retry again rather than staying terminal.
        var fail = true;
        when(() => repository.syncProgressBatch(any())).thenAnswer(
          (_) async => fail
              ? const Left(ServerFailure('down'))
              : const Right(null),
        );

        bounded.enqueue(
          const LessonProgressSyncItem(
            courseId: 'c1',
            lessonId: 'l1',
            completed: false,
            progressPct: 10,
          ),
          flushNow: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(verify(() => repository.syncProgressBatch(any())).callCount, 2);

        fail = false;
        bounded.enqueue(
          const LessonProgressSyncItem(
            courseId: 'c1',
            lessonId: 'l2',
            completed: true,
            progressPct: 100,
          ),
          flushNow: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        // The l2 item flushed successfully; the budget is now reset.
        fail = true;
        bounded.enqueue(
          const LessonProgressSyncItem(
            courseId: 'c1',
            lessonId: 'l3',
            completed: false,
            progressPct: 50,
          ),
          flushNow: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // l3's initial flush + 2 budgeted retries happened again.
        expect(
          verify(() => repository.syncProgressBatch(any())).callCount,
          greaterThanOrEqualTo(3),
        );

        await bounded.dispose();
      },
    );
  });

  // ─── Disk outbox (Phase 9: no silent progress loss on app kill) ──────────
  //
  // The pending queue used to be memory-only: killing the app (no logout,
  // no dispose) silently dropped every unacknowledged progress write. The
  // outbox snapshots the queue under the signed-in account's key and
  // restores it for that SAME account on the next openSession.
  group('disk outbox', () {
    Future<Map<String, Object>> prefsMap() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs
          .getKeys()
          .fold<Map<String, Object>>({}, (acc, key) {
            final value = prefs.get(key);
            if (value != null) acc[key] = value;
            return acc;
          });
    }

    test(
      'progress queued before an app kill is restored and flushed when the '
      'same account reopens a session',
      () async {
        // "Session 1": account A queues progress, then the process dies
        // (no flush — the idle timer is minutes away, like the real 10s
        // one is far beyond this test's lifetime).
        final killed = LessonProgressSyncEngine(
          syncLessonProgress: SyncLessonProgress(repository),
          outboxStore: LessonProgressOutboxStore(),
          flushInterval: const Duration(minutes: 1),
        );
        killed.openSession('user-A');
        killed.enqueue(
          const LessonProgressSyncItem(
            courseId: 'course-a',
            lessonId: 'lesson-a',
            completed: false,
            progressPct: 42,
            watchTimeSec: 90,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(killed.pendingCount, 1);
        final disk = await prefsMap();
        expect(disk.containsKey('progress_outbox_v1_user-A'), isTrue);
        // (killed is intentionally never disposed — that is the app kill.)

        // "Session 2": the same account reopens; the snapshot must come
        // back and reach the server.
        clearInteractions(repository);
        final revived = LessonProgressSyncEngine(
          syncLessonProgress: SyncLessonProgress(repository),
          outboxStore: LessonProgressOutboxStore(),
          flushInterval: const Duration(milliseconds: 10),
        );
        revived.openSession('user-A');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(
          () => repository.syncProgressBatch(
            any(
              that: predicate<List<LessonProgressSyncItem>>(
                (items) =>
                    items.length == 1 &&
                    items.single.courseId == 'course-a' &&
                    items.single.lessonId == 'lesson-a' &&
                    items.single.progressPct == 42 &&
                    items.single.watchTimeSec == 90,
              ),
            ),
          ),
        ).called(1);
        expect(revived.pendingCount, 0);
        // A clean flush removes the snapshot instead of leaving a stale
        // file that would re-restore already-acknowledged progress.
        final diskAfter = await prefsMap();
        expect(diskAfter.containsKey('progress_outbox_v1_user-A'), isFalse);
      },
    );

    test(
      'account B never restores (or flushes) account A outbox entries, and '
      "B's session does not destroy A's snapshot",
      () async {
        final killed = LessonProgressSyncEngine(
          syncLessonProgress: SyncLessonProgress(repository),
          outboxStore: LessonProgressOutboxStore(),
          flushInterval: const Duration(minutes: 1),
        );
        killed.openSession('user-A');
        killed.enqueue(
          const LessonProgressSyncItem(
            courseId: 'course-a',
            lessonId: 'lesson-a',
            completed: false,
            progressPct: 42,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        clearInteractions(repository);
        final asUserB = LessonProgressSyncEngine(
          syncLessonProgress: SyncLessonProgress(repository),
          outboxStore: LessonProgressOutboxStore(),
          flushInterval: const Duration(milliseconds: 10),
        );
        asUserB.openSession('user-B');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(asUserB.pendingCount, 0);
        verifyNever(
          () => repository.syncProgressBatch(
            any(
              that: predicate<List<LessonProgressSyncItem>>(
                (items) => items.any((i) => i.courseId == 'course-a'),
              ),
            ),
          ),
        );

        // B closes their session (their own, empty outbox is cleared); A's
        // snapshot must still be on disk, because B's boundary has no
        // authority over A's account-scoped key.
        await asUserB.closeSession();
        final disk = await prefsMap();
        expect(disk.containsKey('progress_outbox_v1_user-A'), isTrue);
      },
    );

    test('closeSession deletes the owning account snapshot', () async {
      engine.openSession('user-A');
      engine.enqueue(
        const LessonProgressSyncItem(
          courseId: 'course-a',
          lessonId: 'lesson-a',
          completed: false,
          progressPct: 10,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (await prefsMap()).containsKey('progress_outbox_v1_user-A'),
        isTrue,
      );

      await engine.closeSession();
      expect(
        (await prefsMap()).containsKey('progress_outbox_v1_user-A'),
        isFalse,
        reason:
            'a session boundary must take its account outbox with it — a '
            'queued write may never outlive the session that owns it',
      );
    });

    test(
        'a persist still in flight cannot resurrect the snapshot after '
        'closeSession', () async {
      engine.openSession('user-A');
      // The enqueue's disk persist is fire-and-forget; closeSession is
      // issued while that save may still be queued. The store serializes
      // its operations, so the clear must land last — regression for the
      // resurrection race found by this suite (Phase 9).
      engine.enqueue(
        const LessonProgressSyncItem(
          courseId: 'course-a',
          lessonId: 'lesson-a',
          completed: false,
          progressPct: 10,
        ),
      );
      await engine.closeSession();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        (await prefsMap()).containsKey('progress_outbox_v1_user-A'),
        isFalse,
        reason:
            'an in-flight persist must never re-create the outbox key after '
            'its own session boundary has deleted it',
      );
    });

    test('a corrupted snapshot is discarded, not guessed at', () async {
      SharedPreferences.setMockInitialValues({
        'progress_outbox_v1_user-A': 'not-json{{{',
      });
      engine.openSession('user-A');
      await Future<void>.delayed(Duration.zero);
      expect(engine.pendingCount, 0);
      expect(
        (await prefsMap()).containsKey('progress_outbox_v1_user-A'),
        isFalse,
      );

      // Wrong schema version: treated the same way — discard, never
      // interpret unknown data as progress.
      SharedPreferences.setMockInitialValues({
        'progress_outbox_v1_user-A': jsonEncode({'v': 99, 'items': []}),
      });
      engine.openSession('user-A');
      await Future<void>.delayed(Duration.zero);
      expect(engine.pendingCount, 0);
    });

    test('a snapshot with malformed entries restores only the valid rows',
        () async {
      SharedPreferences.setMockInitialValues({
        'progress_outbox_v1_user-A': jsonEncode({
          'v': 1,
          'items': [
            {
              'courseId': 'course-ok',
              'lessonId': 'lesson-ok',
              'completed': false,
              'progressPct': 30,
            },
            {
              'courseId': 'course-bad',
              // missing lessonId / completed / progressPct types
            },
            'garbage-entry',
          ],
        }),
      });
      engine.openSession('user-A');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The restore itself flushes the recovered rows; after the flush the
      // in-memory queue is empty again — the assertion of success is the
      // batch reaching the repository below.
      expect(engine.pendingCount, 0);
      verify(
        () => repository.syncProgressBatch(
          any(
            that: predicate<List<LessonProgressSyncItem>>(
              (items) =>
                  items.single.courseId == 'course-ok' &&
                  items.single.lessonId == 'lesson-ok' &&
                  items.single.progressPct == 30,
            ),
          ),
        ),
      ).called(1);
    });

    test('restore merges with progress already queued in this session',
        () async {
      SharedPreferences.setMockInitialValues({
        'progress_outbox_v1_user-A': jsonEncode({
          'v': 1,
          'items': [
            {
              'courseId': 'c1',
              'lessonId': 'l1',
              'completed': false,
              'progressPct': 30,
              'watchTimeSec': 50,
            },
          ],
        }),
      });
      engine.openSession('user-A');
      // Racing enqueue in the fresh session (the async restore may not have
      // applied yet) — the merge must keep both, monotonic per key.
      engine.enqueue(
        const LessonProgressSyncItem(
          courseId: 'c1',
          lessonId: 'l1',
          completed: false,
          progressPct: 80,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.pendingCount, 0);
      verify(
        () => repository.syncProgressBatch(
          any(
            that: predicate<List<LessonProgressSyncItem>>(
              (items) =>
                  items.single.progressPct == 80 &&
                  items.single.watchTimeSec == 50,
            ),
          ),
        ),
      ).called(1);
    });
  });

  // Phase 10 (connectivity): a reconnect is transient, not a deterministic
  // failure — it must clear the exhausted retry budget and push whatever is
  // still pending, instead of waiting for the next user-driven enqueue.
  group('flushOnReconnect', () {
    test('flushes pending items and resets the failure budget', () async {
      // Exhaust the budget: maxConsecutiveFailures defaults to 6; 7 failures
      // guarantee the idle-timer cadence has stopped.
      var fail = true;
      when(
        () => repository.syncProgressBatch(any()),
      ).thenAnswer(
        (_) async => fail
            ? const Left(ServerFailure('offline'))
            : const Right(null),
      );

      engine.enqueue(
        const LessonProgressSyncItem(
          courseId: 'c1',
          lessonId: 'l1',
          completed: false,
          progressPct: 30,
        ),
        flushNow: true,
      );
      for (var i = 0; i < 7; i++) {
        await engine.flush();
      }
      expect(engine.pendingCount, 1, reason: 'failed items are kept');
      clearInteractions(repository);

      // Connectivity returns.
      fail = false;
      await engine.flushOnReconnect();
      await Future<void>.delayed(Duration.zero);

      expect(engine.pendingCount, 0);
      verify(() => repository.syncProgressBatch(any())).called(1);
    });

    test('is a no-op when nothing is pending', () async {
      await engine.flushOnReconnect();
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => repository.syncProgressBatch(any()));
    });
  });
}
