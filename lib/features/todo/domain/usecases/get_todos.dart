import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/todo_item.dart';
import '../repositories/todo_repository.dart';

class GetTodos {
  final TodoRepository repository;

  GetTodos(this.repository);

  Future<Either<Failure, List<TodoItem>>> call() {
    return repository.fetchTodos();
  }
}
