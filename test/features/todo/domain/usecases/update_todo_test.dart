import 'package:app/features/todo/domain/entities/todo_item.dart';
import 'package:app/features/todo/domain/repositories/todo_repository.dart';
import 'package:app/features/todo/domain/usecases/update_todo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeTodoItem extends Fake implements TodoItem {}

void main() {
  late UpdateTodo usecase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTodoItem());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = UpdateTodo(mockRepository);
  });

  const tTodo = TodoItem(
    id: '1',
    userId: 'u1',
    tenantId: 't1',
    title: 'Test',
  );

  test('should delegate to repository.updateTodo', () async {
    // arrange
    when(
      () => mockRepository.updateTodo(any()),
    ).thenAnswer((_) async => const Right(null));

    // act
    final result = await usecase(tTodo);

    // assert
    expect(result, const Right(null));
    verify(() => mockRepository.updateTodo(tTodo)).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
