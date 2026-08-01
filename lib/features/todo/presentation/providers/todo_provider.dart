import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
  @override
  TodoState build() {
    // We can't call async methods directly in build if we want to return immediate state.
    // However, we can use future to initialize or just trigger the fetch.
    Future.microtask(() => fetchTodos());
    return TodoState();
  }

  Future<void> fetchTodos() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await ref.read(getTodosProvider).call();

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (todos) => state = state.copyWith(isLoading: false, todos: todos),
    );
  }

  Future<void> toggleTodoStatus(String todoId, bool currentStatus) async {
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
    // Optimistic update
    final initialTodos = state.todos;
    state = state.copyWith(todos: [newTodo, ...initialTodos]);

    final result = await ref.read(addTodoProvider).call(newTodo);

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
    // Optimistic update
    final initialTodos = state.todos;
    final updatedTodos = initialTodos.where((t) => t.id != todoId).toList();

    state = state.copyWith(todos: updatedTodos);

    final result = await ref.read(deleteTodoProvider).call(todoId);

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
    // Optimistic update
    final initialTodos = state.todos;
    final updatedList = initialTodos.map((t) {
      if (t.id == updatedTodo.id) return updatedTodo;
      return t;
    }).toList();

    state = state.copyWith(todos: updatedList);

    final result = await ref.read(updateTodoProvider).call(updatedTodo);

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