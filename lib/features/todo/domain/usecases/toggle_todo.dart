import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/todo_repository.dart';

class ToggleTodo {
  final TodoRepository repository;

  ToggleTodo(this.repository);

  Future<Either<Failure, void>> call(String todoId, bool isCompleted) {
    return repository.toggleTodoStatus(todoId, isCompleted);
  }
}
