import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/todo_item.dart';

abstract class TodoRepository {
  Future<Either<Failure, List<TodoItem>>> fetchTodos();
  Future<Either<Failure, void>> toggleTodoStatus(String todoId, bool isCompleted);
  Future<Either<Failure, void>> addTodo(TodoItem todo);
  Future<Either<Failure, void>> deleteTodo(String todoId);
  Future<Either<Failure, void>> updateTodo(TodoItem todo);

}
