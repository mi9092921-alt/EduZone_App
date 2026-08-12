import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/todo_repository.dart';

class DeleteTodo {
  final TodoRepository repository;

  DeleteTodo(this.repository);

  Future<Either<Failure, void>> call(String todoId) {
    return repository.deleteTodo(todoId);
  }
}
