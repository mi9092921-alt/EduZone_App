import '../../domain/entities/todo_item.dart';

abstract class TodoRemoteDataSource {
  Future<List<TodoItem>> fetchTodos(String userId);
  Future<void> toggleTodoStatus(String todoId, bool isCompleted);
  Future<void> addTodo(TodoItem todo);
  Future<void> updateTodo(TodoItem todo);
  Future<void> deleteTodo(String todoId);
}
