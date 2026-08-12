import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/todo_item.dart';
import '../repositories/todo_repository.dart';

class UpdateTodo {
  final TodoRepository repository;

  UpdateTodo(this.repository);

  Future<Either<Failure, void>> call(TodoItem todo) {
    return repository.updateTodo(todo);
  }
}
