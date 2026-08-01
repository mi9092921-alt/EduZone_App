import 'package:app/features/todo/domain/entities/todo_item.dart';
import 'package:app/features/todo/domain/repositories/todo_repository.dart';
import 'package:app/features/todo/domain/usecases/add_todo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late AddTodo usecase;
  late MockTodoRepository mockRepo;

  setUp(() {
    mockRepo = MockTodoRepository();
    usecase = AddTodo(mockRepo);
  });

  final tTodo = TodoItem(
    id: '1',
    userId: 'u1',
    tenantId: 't1',
    title: 'New Task',
    createdAt: DateTime.now(),
  );

  test('should add todo to repository', () async {
    // arrange
    when(
      () => mockRepo.addTodo(tTodo),
    ).thenAnswer((_) async => const Right(null));

    // act
    final result = await usecase(tTodo);

    // assert
    expect(result, const Right(null));
    verify(() => mockRepo.addTodo(tTodo));
    verifyNoMoreInteractions(mockRepo);
  });
}
