import 'package:app/core/error/failures.dart';
import 'package:app/core/logging/domain/app_event.dart';
import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:app/core/logging/logging_providers.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/todo/application/providers/todo_provider.dart';
import 'package:app/features/todo/domain/repositories/todo_repository.dart';
import 'package:app/shared/models/account_status.dart';
import 'package:app/shared/models/app_user.dart';
import 'package:app/shared/models/auth_state.dart';
import 'package:app/shared/models/todo_item.dart';
import 'package:app/shared/models/user_access.dart';
import 'package:app/shared/models/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockTodoRepository extends Mock implements TodoRepository {}

class MockEventBus extends Mock implements EventBus {}

class _FakeAuthNotifier extends Auth {
  _FakeAuthNotifier([this.authenticatedUser]);

  /// When non-null the notifier builds as [AuthAuthenticated] so the
  /// telemetry-emitting paths (TodoCompletedEvent/TodoCreatedEvent) run.
  final AppUser? authenticatedUser;

  @override
  AuthState build() {
    final user = authenticatedUser;
    if (user == null) return const AuthUnauthenticated();
    return AuthAuthenticated(
      user: user,
      access: const UserAccess(
        status: AccountStatus.active,
        role: UserRole.student,
      ),
    );
  }
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

TodoItem _todo(String id, {String title = 'Todo'}) {
  return TodoItem(id: id, userId: 'user-1', tenantId: 'tenant-1', title: title);
}

const _testUser = AppUser(
  id: 'user-1',
  email: 'user1@example.com',
  firstName: 'Test',
  lastName: 'User',
  tenantId: 'tenant-1',
);



/// Drains pending microtasks so chained/awaited futures inside the notifier
/// have a chance to settle before assertions. Mirrors the pattern already
/// used in downloads_notifier_test.dart for the same class of timing issue.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockTodoRepository repository;
  late MockEventBus eventBus;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_todo('fallback'));
    // AppEvent is sealed — a concrete event is a valid fallback for
    // capturing emitted events of any subtype.
    registerFallbackValue(
      TodoCreatedEvent(timestamp: DateTime(2024), todoId: 'fallback'),
    );
  });

  setUp(() {
    repository = MockTodoRepository();
    eventBus = MockEventBus();
    container = ProviderContainer(
      overrides: [
        todoRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(() => _FakeAuthNotifier()),
        eventBusProvider.overrideWithValue(eventBus),
      ],
    );
    addTearDown(container.dispose);
  });

  group('TodoNotifier.deleteTodo — mutation-queue serialization (STATE-005)', () {
    test(
      "a queued addTodo's optimistic update survives a preceding "
      "deleteTodo's post-success refresh, instead of being silently "
      'overwritten by it',
      () async {
        // Build with an empty list.
        when(() => repository.fetchTodos()).thenAnswer((_) async => const Right([]));
        container.listen(todoProvider, (_, _) {});
        await container.read(todoProvider.notifier).fetchTodos();
        await _settle();
        expect(container.read(todoProvider).todos, isEmpty);

        // deleteTodo's own network call resolves quickly...
        when(
          () => repository.deleteTodo(any()),
        ).thenAnswer((_) async => const Right(null));
        // ...but the server-authoritative refresh it triggers on success is
        // slower, and (deliberately, to prove the fix) still reports the
        // pre-add list -- simulating that this refresh request left the
        // client *before* the queued addTodo below was even sent.
        when(() => repository.fetchTodos()).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const Right([]);
        });
        // addTodo's own network call resolves essentially immediately.
        when(
          () => repository.addTodo(any()),
        ).thenAnswer((_) async => const Right(null));

        final notifier = container.read(todoProvider.notifier);

        // Fire both mutations back-to-back without awaiting the first, the
        // way two quick user taps would. If the delete's refresh is not
        // properly serialized inside the mutation queue, its slower
        // stale-data response can land *after* addTodo's optimistic
        // update and wipe it out.
        final deleteFuture = notifier.deleteTodo('irrelevant-id');
        final addFuture = notifier.addTodo(_todo('new-todo', title: 'New'));

        await deleteFuture;
        await addFuture;
        await _settle();

        expect(
          container.read(todoProvider).todos.map((t) => t.id),
          contains('new-todo'),
          reason:
              "addTodo's optimistic update must not be silently overwritten "
              "by deleteTodo's post-success refresh landing later",
        );
      },
    );
  });

  group('TodoNotifier.fetchTodos', () {
    test('loads the repository list into state', () async {
      when(() => repository.fetchTodos())
          .thenAnswer((_) async => Right([_todo('t1'), _todo('t2')]));
      container.listen(todoProvider, (_, _) {});

      await container.read(todoProvider.notifier).fetchTodos();
      await _settle();

      final state = container.read(todoProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.todos.map((t) => t.id), ['t1', 't2']);
    });

    test('stores the typed failure without losing the current list',
        () async {
      const failure = ServerFailure('offline');
      when(() => repository.fetchTodos()).thenAnswer((_) async => const Left(failure));
      container.listen(todoProvider, (_, _) {});

      await container.read(todoProvider.notifier).fetchTodos();
      await _settle();

      final state = container.read(todoProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, same(failure));
      expect(state.todos, isEmpty);
    });
  });

  group('TodoNotifier.addTodo', () {
    test('inserts the new todo optimistically and succeeds', () async {
      when(() => repository.fetchTodos())
          .thenAnswer((_) async => const Right([]));
      when(() => repository.addTodo(any()))
          .thenAnswer((_) async => const Right(null));
      container.listen(todoProvider, (_, _) {});
      await container.read(todoProvider.notifier).fetchTodos();
      await _settle();

      await container.read(todoProvider.notifier).addTodo(_todo('new-1'));

      await _settle();
      final state = container.read(todoProvider);
      expect(state.error, isNull);
      expect(state.todos.map((t) => t.id), contains('new-1'));
      verify(() => repository.addTodo(any())).called(1);
    });

    test('reverts the optimistic insert when the repository fails',
        () async {
      const failure = ServerFailure('insert rejected');
      when(() => repository.fetchTodos())
          .thenAnswer((_) async => Right([_todo('existing')]));
      when(() => repository.addTodo(any()))
          .thenAnswer((_) async => const Left(failure));
      container.listen(todoProvider, (_, _) {});
      await container.read(todoProvider.notifier).fetchTodos();
      await _settle();

      await container.read(todoProvider.notifier).addTodo(_todo('new-1'));

      await _settle();
      final state = container.read(todoProvider);
      expect(state.error, same(failure));
      // The optimistic entry is gone again; the pre-existing todo stays.
      expect(state.todos.map((t) => t.id), ['existing']);
    });
  });

  group('TodoNotifier.toggleTodoStatus', () {
    test('flips the todo optimistically and emits TodoCompletedEvent for an '
        'authenticated user completing a task', () async {
      when(() => repository.fetchTodos())
          .thenAnswer((_) async => Right([_todo('t1')]));
      when(() => repository.toggleTodoStatus(any(), any()))
          .thenAnswer((_) async => const Right(null));
      final authenticatedContainer = ProviderContainer(
        overrides: [
          todoRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith(() => _FakeAuthNotifier(_testUser)),
          eventBusProvider.overrideWithValue(eventBus),
        ],
      );
      addTearDown(authenticatedContainer.dispose);
      authenticatedContainer.listen(todoProvider, (_, _) {});
      await authenticatedContainer.read(todoProvider.notifier).fetchTodos();
      await _settle();

      await authenticatedContainer
          .read(todoProvider.notifier)
          .toggleTodoStatus('t1', false);
      await _settle();

      final state = authenticatedContainer.read(todoProvider);
      expect(state.error, isNull);
      expect(state.todos.single.isCompleted, isTrue);
      verify(() => repository.toggleTodoStatus('t1', true)).called(1);
      final emitted = verify(
        () => eventBus.emit(captureAny()),
      ).captured.single as TodoCompletedEvent;
      expect(emitted.todoId, 't1');
      expect(emitted.userId, _testUser.id);
      expect(emitted.tenantId, _testUser.tenantId);
    });

    test('reverts the optimistic flip and emits no event when the '
        'repository fails', () async {
      const failure = ServerFailure('toggle rejected');
      when(() => repository.fetchTodos())
          .thenAnswer((_) async => Right([_todo('t1')]));
      when(() => repository.toggleTodoStatus(any(), any()))
          .thenAnswer((_) async => const Left(failure));
      container.listen(todoProvider, (_, _) {});
      await container.read(todoProvider.notifier).fetchTodos();
      await _settle();

      await container.read(todoProvider.notifier).toggleTodoStatus('t1', false);
      await _settle();

      final state = container.read(todoProvider);
      expect(state.error, same(failure));
      expect(state.todos.single.isCompleted, isFalse);
      verifyNever(() => eventBus.emit(any()));
    });
  });

  group('TodoNotifier.updateTodo', () {
    test('replaces the matching todo in the list', () async {
      when(() => repository.fetchTodos())
          .thenAnswer((_) async => Right([_todo('t1'), _todo('t2')]));
      when(() => repository.updateTodo(any()))
          .thenAnswer((_) async => const Right(null));
      container.listen(todoProvider, (_, _) {});
      await container.read(todoProvider.notifier).fetchTodos();
      await _settle();

      await container
          .read(todoProvider.notifier)
          .updateTodo(_todo('t1', title: 'Renamed'));
      await _settle();

      final state = container.read(todoProvider);
      expect(state.error, isNull);
      expect(state.todos.map((t) => t.title), ['Renamed', 'Todo']);
    });
  });
}
