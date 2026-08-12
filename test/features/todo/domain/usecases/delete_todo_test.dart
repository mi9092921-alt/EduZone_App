import 'package:app/features/todo/domain/repositories/todo_repository.dart';
import 'package:app/features/todo/domain/usecases/delete_todo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late DeleteTodo usecase;
  late MockTodoRepository mockRepo;

  setUp(() {
    mockRepo = MockTodoRepository();
    usecase = DeleteTodo(mockRepo);
  });

  const tTodoId = '1';

  test('should call deleteTodo on repository', () async {
    // arrange
    when(
      () => mockRepo.deleteTodo(tTodoId),
    ).thenAnswer((_) async => const Right(null));

    // act
    final result = await usecase(tTodoId);

    // assert
    expect(result, const Right(null));
    verify(() => mockRepo.deleteTodo(tTodoId));
    verifyNoMoreInteractions(mockRepo);
  });
}
