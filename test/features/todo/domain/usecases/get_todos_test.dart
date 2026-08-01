import 'package:app/features/todo/domain/entities/todo_item.dart';
import 'package:app/features/todo/domain/repositories/todo_repository.dart';
import 'package:app/features/todo/domain/usecases/get_todos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late GetTodos usecase;
  late MockTodoRepository mockRepo;

  setUp(() {
    mockRepo = MockTodoRepository();
    usecase = GetTodos(mockRepo);
  });

  final List<TodoItem> tTodos = [
    TodoItem(
      id: '1',
      userId: 'usr',
      tenantId: 'tenant1',
      title: 'Task 1',
      createdAt: DateTime.now(),
    ),
  ];

  test('should get todos from repository', () async {
    // arrange
    when(() => mockRepo.fetchTodos()).thenAnswer((_) async => Right(tTodos));

    // act
    final result = await usecase();

    // assert
    expect(result.fold((l) => null, (r) => r), tTodos);
    verify(() => mockRepo.fetchTodos());
    verifyNoMoreInteractions(mockRepo);
  });
}
