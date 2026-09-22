import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import '../../../../shared/models/auth_state.dart';
import '../../../../shared/models/todo_item.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../data/datasources/todo_remote_ds_impl.dart';
import '../../data/repositories/todo_repo_impl.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/add_todo.dart';
import '../../domain/usecases/delete_todo.dart';
import '../../domain/usecases/get_todos.dart';
import '../../domain/usecases/toggle_todo.dart';
import '../../domain/usecases/update_todo.dart';

part 'todo_provider.g.dart';

@riverpod
TodoRemoteDataSourceImpl todoRemoteDataSource(Ref ref) {
  return TodoRemoteDataSourceImpl(supabaseClient: ref.watch(supabaseClientProvider));
}

@riverpod
TodoRepository todoRepository(Ref ref) {
  return TodoRepositoryImpl(
    remoteDataSource: ref.watch(todoRemoteDataSourceProvider),
  );
}

@riverpod
GetTodos getTodos(Ref ref) => GetTodos(ref.watch(todoRepositoryProvider));

@riverpod
AddTodo addTodo(Ref ref) => AddTodo(ref.watch(todoRepositoryProvider));

@riverpod
ToggleTodo toggleTodo(Ref ref) => ToggleTodo(ref.watch(todoRepositoryProvider));

@riverpod
DeleteTodo deleteTodo(Ref ref) => DeleteTodo(ref.watch(todoRepositoryProvider));

@riverpod
UpdateTodo updateTodo(Ref ref) => UpdateTodo(ref.watch(todoRepositoryProvider));

class TodoState {
  final List<TodoItem> todos;
  final bool isLoading;

  /// The [Failure] from the last failed operation, or `null`. Kept as the
  /// typed [Failure] (not a pre-formatted `String`) so the screen can
  /// classify it via `ErrorHandler.getMessage()` at display time -- the
  /// notifier layer has no `BuildContext`/localization access, so
  /// classification can't happen here. Previously this stored
  /// `failure.message` directly: an internal, English-only diagnostic
  /// string never meant to be user-facing, shown as-is regardless of
  /// locale (see Section 13/14 hardening pass).
  final Object? error;

  TodoState({this.todos = const [], this.isLoading = false, this.error});

  TodoState copyWith({
    List<TodoItem>? todos,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return TodoState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@riverpod
class TodoNotifier extends _$TodoNotifier {
  int _buildGeneration = 0;
  int _fetchGeneration = 0;
  Future<void> _mutationQueue = Future<void>.value();

  bool _isCurrent(int buildGeneration, int fetchGeneration) {
    return ref.mounted &&
        buildGeneration == _buildGeneration &&
        fetchGeneration == _fetchGeneration;
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final operation = _mutationQueue.then<T>((_) => mutation());
    _mutationQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  TodoState build() {
    final buildGeneration = ++_buildGeneration;
    ++_fetchGeneration;
    // The initial fetch is intentionally scheduled after build returns so the
    // notifier exposes a deterministic initial state first.
    Future.microtask(() {
      if (ref.mounted && buildGeneration == _buildGeneration) {
        unawaited(_fetchTodos(buildGeneration));
      }
    });
    return TodoState();
  }

  Future<void> fetchTodos() async {
    // Runs inside the same serialization queue as every mutation: a
    // pull-to-refresh that raced an in-flight optimistic add/toggle used to
    // overwrite the optimistic state with the server's pre-mutation list
    // (the new todo visually vanished / the toggle visually reverted), and
    // the mutation's success branch never reconciled. Queueing makes
    // refresh wait for pending mutations, so the server read it performs
    // already includes them.
    await _enqueueMutation(() async {
      await _fetchTodos(_buildGeneration);
    });
  }

  Future<void> _fetchTodos(int buildGeneration) async {
    final fetchGeneration = ++_fetchGeneration;
    if (!ref.mounted || buildGeneration != _buildGeneration) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final result = await ref.read(getTodosProvider).call();

    if (!_isCurrent(buildGeneration, fetchGeneration)) return;

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure),
      (todos) => state = state.copyWith(isLoading: false, todos: todos),
    );
  }

  /// Returns whether the toggle was applied (false on failure — the error
  /// is stored in [TodoState.error]). Lets callers distinguish an
  /// acknowledged mutation from a silent failure instead of assuming
  /// success.
  Future<bool> toggleTodoStatus(String todoId, bool currentStatus) {
    return _enqueueMutation(() => _toggleTodoStatus(todoId, currentStatus));
  }

  void _notifyTodoListChanged() {
    // Phase 10: telemetry-silent UI refresh signal — home's "Daily tasks"
    // preview invalidates recentTodosProvider on this (see
    // home_refresh_listener.dart). See TodoListChangedEvent's doc for why
    // this is category `ui` (never written to the activity log).
    ref.read(eventBusProvider).emit(TodoListChangedEvent(timestamp: DateTime.now()));
  }

  Future<bool> _toggleTodoStatus(String todoId, bool currentStatus) async {
    final buildGeneration = _buildGeneration;
    // Optimistic update
    final initialTodos = state.todos;
    final updatedTodos = initialTodos.map((t) {
      if (t.id == todoId) {
        return t.copyWith(isCompleted: !currentStatus);
      }
      return t;
    }).toList();

    state = state.copyWith(todos: updatedTodos);

    final result = await ref
        .read(toggleTodoProvider)
        .call(todoId, !currentStatus);

    if (!ref.mounted || buildGeneration != _buildGeneration) return false;

    var success = false;
    result.fold(
      (failure) {
        // Revert on failure
        state = state.copyWith(error: failure, todos: initialTodos);
      },
      (_) {
        success = true;
        _notifyTodoListChanged();
        // Success
        final authState = ref.read(authProvider);
        if (!currentStatus && authState is AuthAuthenticated) {
          // If was not completed, and now is completed
          final user = authState.user;
          ref
              .read(eventBusProvider)
              .emit(
                TodoCompletedEvent(
                  timestamp: DateTime.now(),
                  userId: user.id,
                  tenantId: user.tenantId,
                  todoId: todoId,
                ),
              );
        }
      },
    );
    return success;
  }

  /// Returns whether the todo was created (false on failure — the error is
  /// stored in [TodoState.error]).
  Future<bool> addTodo(TodoItem newTodo) {
    return _enqueueMutation(() => _addTodo(newTodo));
  }

  Future<bool> _addTodo(TodoItem newTodo) async {
    final buildGeneration = _buildGeneration;
    // Optimistic update
    final initialTodos = state.todos;
    state = state.copyWith(todos: [newTodo, ...initialTodos]);

    final result = await ref.read(addTodoProvider).call(newTodo);

    if (!ref.mounted || buildGeneration != _buildGeneration) return false;

    var success = false;
    result.fold(
      (failure) {
        state = state.copyWith(error: failure, todos: initialTodos);
      },
      (_) {
        success = true;
        _notifyTodoListChanged();
        // Success
        final authState = ref.read(authProvider);
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          ref
              .read(eventBusProvider)
              .emit(
                TodoCreatedEvent(
                  timestamp: DateTime.now(),
                  userId: user.id,
                  tenantId: user.tenantId,
                  todoId: newTodo.id,
                ),
              );
        }
      },
    );
    return success;
  }

  Future<bool> deleteTodo(String todoId) async {
    return await _enqueueMutation(() => _deleteTodo(todoId));
  }

  Future<bool> _deleteTodo(String todoId) async {
    final buildGeneration = _buildGeneration;
    // Optimistic update
    final initialTodos = state.todos;
    final updatedTodos = initialTodos.where((t) => t.id != todoId).toList();

    state = state.copyWith(todos: updatedTodos);

    final result = await ref.read(deleteTodoProvider).call(todoId);

    if (!ref.mounted || buildGeneration != _buildGeneration) return false;

    final success = result.fold((failure) {
      debugPrint('[TodoNotifier] deleteTodo failed: ${failure.message}');
      state = state.copyWith(error: failure, todos: initialTodos);
      return false;
    }, (_) {
      _notifyTodoListChanged();
      return true;
    });

    if (success) {
      // Server confirmed deletion — refresh to stay in sync. Uses the
      // internal _fetchTodos (not the public fetchTodos() wrapper), with
      // the buildGeneration already captured above, and IS awaited (unlike
      // the previous fire-and-forget `fetchTodos();`) so this refresh runs
      // to completion inside the current _enqueueMutation slot instead of
      // racing the next queued mutation. A fire-and-forget refresh here
      // could otherwise resolve *after* e.g. a queued addTodo's optimistic
      // update and silently overwrite it with the stale pre-delete list,
      // making the newly added todo appear to vanish until the next
      // explicit refresh.
      await _fetchTodos(buildGeneration);
    }
    return success;
  }

  /// Returns whether the todo was updated (false on failure — the error is
  /// stored in [TodoState.error]). A false for an already-deleted todo is
  /// NOT produced here: the server UPDATE matching 0 rows still succeeds,
  /// so a deleted-then-edited todo reports success — the sheet treats
  /// success as authoritative.
  Future<bool> updateTodo(TodoItem updatedTodo) {
    return _enqueueMutation(() => _updateTodo(updatedTodo));
  }

  Future<bool> _updateTodo(TodoItem updatedTodo) async {
    final buildGeneration = _buildGeneration;
    // Optimistic update
    final initialTodos = state.todos;
    final updatedList = initialTodos.map((t) {
      if (t.id == updatedTodo.id) return updatedTodo;
      return t;
    }).toList();

    state = state.copyWith(todos: updatedList);

    final result = await ref.read(updateTodoProvider).call(updatedTodo);

    if (!ref.mounted || buildGeneration != _buildGeneration) return false;

    var success = false;
    result.fold(
      (failure) {
        state = state.copyWith(error: failure, todos: initialTodos);
      },
      (_) {
        success = true;
        _notifyTodoListChanged();
      },
    );
    return success;
  }
}

// ─── Session cleanup ─────────────────────────────────────────────────────────

/// Invalidates every user-scoped provider owned by the `todo` feature.
/// Called by [Auth.logout]. When you add a new user-scoped provider to this
/// file, add it here too.
void invalidateTodoProviders(Ref ref) {
  ref.invalidate(todoProvider);
  ref.invalidate(todoRemoteDataSourceProvider);
}
