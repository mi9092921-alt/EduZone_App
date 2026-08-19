import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../shared/cross_feature/auth_shared.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../data/datasources/todo_remote_ds_impl.dart';
import '../../data/repositories/todo_repo_impl.dart';
import '../../domain/entities/todo_item.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/add_todo.dart';
import '../../domain/usecases/delete_todo.dart';
import '../../domain/usecases/get_todos.dart';
import '../../domain/usecases/toggle_todo.dart';
import '../../domain/usecases/update_todo.dart';

part 'todo_provider.g.dart';

@riverpod
TodoRemoteDataSourceImpl todoRemoteDataSource(Ref ref) {
  return TodoRemoteDataSourceImpl(supabaseClient: SupabaseService.client);
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
  final String? error;

  TodoState({this.todos = const [], this.isLoading = false, this.error});

  TodoState copyWith({
    List<TodoItem>? todos,
    bool? isLoading,
    String? error,
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
    final buildGeneration = _buildGeneration;
    await _fetchTodos(buildGeneration);
  }

  Future<void> _fetchTodos(int buildGeneration) async {
    final fetchGeneration = ++_fetchGeneration;
    if (!ref.mounted || buildGeneration != _buildGeneration) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final result = await ref.read(getTodosProvider).call();

    if (!_isCurrent(buildGeneration, fetchGeneration)) return;

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (todos) => state = state.copyWith(isLoading: false, todos: todos),
    );
  }

  Future<void> toggleTodoStatus(String todoId, bool currentStatus) async {
    await _enqueueMutation(() async {
      await _toggleTodoStatus(todoId, currentStatus);
    });
  }

  Future<void> _toggleTodoStatus(String todoId, bool currentStatus) async {
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

    if (!ref.mounted || buildGeneration != _buildGeneration) return;

    result.fold(
      (failure) {
        // Revert on failure
        state = state.copyWith(error: failure.message, todos: initialTodos);
      },
      (_) {
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
  }

  Future<void> addTodo(TodoItem newTodo) async {
    await _enqueueMutation(() async {
      await _addTodo(newTodo);
    });
  }

  Future<void> _addTodo(TodoItem newTodo) async {
    final buildGeneration = _buildGeneration;
    // Optimistic update
    final initialTodos = state.todos;
    state = state.copyWith(todos: [newTodo, ...initialTodos]);

    final result = await ref.read(addTodoProvider).call(newTodo);

    if (!ref.mounted || buildGeneration != _buildGeneration) return;

    result.fold(
      (failure) {
        state = state.copyWith(error: failure.message, todos: initialTodos);
      },
      (_) {
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

    return result.fold(
      (failure) {
        debugPrint('[TodoNotifier] deleteTodo failed: ${failure.message}');
        state = state.copyWith(error: failure.message, todos: initialTodos);
        return false;
      },
      (_) {
        // Server confirmed deletion — refresh to stay in sync
        fetchTodos();
        return true;
      },
    );
  }

  Future<void> updateTodo(TodoItem updatedTodo) async {
    await _enqueueMutation(() async {
      await _updateTodo(updatedTodo);
    });
  }

  Future<void> _updateTodo(TodoItem updatedTodo) async {
    final buildGeneration = _buildGeneration;
    // Optimistic update
    final initialTodos = state.todos;
    final updatedList = initialTodos.map((t) {
      if (t.id == updatedTodo.id) return updatedTodo;
      return t;
    }).toList();

    state = state.copyWith(todos: updatedList);

    final result = await ref.read(updateTodoProvider).call(updatedTodo);

    if (!ref.mounted || buildGeneration != _buildGeneration) return;

    result.fold(
      (failure) {
        state = state.copyWith(error: failure.message, todos: initialTodos);
      },
      (_) {
        // Success
      },
    );
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
