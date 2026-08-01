import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/todo_item.dart';
import 'todo_remote_ds.dart';

class TodoRemoteDataSourceImpl implements TodoRemoteDataSource {
  final SupabaseClient supabaseClient;

  TodoRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<TodoItem>> fetchTodos(String userId) async {
    try {
      final response = await supabaseClient
          .from('todos')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('due_at', ascending: true)
          .order('priority', ascending: false);

      return (response as List).map((json) => TodoItem.fromJson(json)).toList();
    } catch (e) {
      throw ServerException('Failed to fetch todos: $e');
    }
  }

  @override
  Future<void> toggleTodoStatus(String todoId, bool isCompleted) async {
    try {
      await supabaseClient
          .from('todos')
          .update({'is_completed': isCompleted})
          .eq('id', todoId);
    } catch (e) {
      throw ServerException('Failed to update todo status: $e');
    }
  }

  @override
  Future<void> addTodo(TodoItem todo) async {
    try {
      debugPrint(
        '[DS] Adding Todo: ${todo.title} with priority: ${todo.priority}',
      );
      await supabaseClient.from('todos').insert({
        'id': todo.id,
        'user_id': todo.userId,
        'tenant_id': todo.tenantId,
        'title': todo.title,
        'due_at': todo.dueAt?.toIso8601String(),
        'priority': todo.priority,
        'deleted_at': null,
        'is_completed': todo.isCompleted,
      });
    } catch (e) {
      throw ServerException('Failed to add todo: $e');
    }
  }

  @override
  Future<void> updateTodo(TodoItem todo) async {
    try {
      await supabaseClient
          .from('todos')
          .update({
            'title': todo.title,
            'due_at': todo.dueAt?.toIso8601String(),
            'priority': todo.priority,
            'is_completed': todo.isCompleted,
            // updated_at is handled by database trigger trg_todos_updated_at
          })
          .eq('id', todo.id);
    } catch (e) {
      throw ServerException('Failed to update todo: $e');
    }
  }

  @override
  Future<void> deleteTodo(String todoId) async {
    try {
      // Soft delete: set deleted_at to now().
      // We don't rely on count() since Supabase may return null or 0
      // even on successful updates when RLS policies are active.
      // Supabase will throw a PostgrestException on actual DB/auth errors.
      await supabaseClient
          .from('todos')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', todoId)
          .isFilter('deleted_at', null);
    } on PostgrestException catch (e) {
      throw ServerException('Failed to delete todo: ${e.message}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to delete todo: $e');
    }
  }
}
