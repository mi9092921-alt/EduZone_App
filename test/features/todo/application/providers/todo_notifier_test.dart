import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:app/core/logging/logging_providers.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/todo/application/providers/todo_provider.dart';
import 'package:app/features/todo/domain/entities/todo_item.dart';
import 'package:app/features/todo/domain/repositories/todo_repository.dart';
import 'package:app/shared/cross_feature/auth_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockTodoRepository extends Mock implements TodoRepository {}

class MockEventBus extends Mock implements EventBus {}

class _FakeAuthNotifier extends Auth {
  @override
  AuthState build() => const AuthUnauthenticated();
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

TodoItem _todo(String id, {String title = 'Todo'}) {
  return TodoItem(id: id, userId: 'user-1', tenantId: 'tenant-1', title: title);
}

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
}
