import 'package:app/features/todo/domain/repositories/todo_repository.dart';
import 'package:app/features/todo/domain/usecases/toggle_todo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late ToggleTodo usecase;
  late MockTodoRepository mockRepo;

  setUp(() {
    mockRepo = MockTodoRepository();
    usecase = ToggleTodo(mockRepo);
  });

  const tTodoId = '1';
  const tIsCompleted = true;

  test('should call toggleTodoStatus on repository', () async {
    // arrange
    when(
      () => mockRepo.toggleTodoStatus(tTodoId, tIsCompleted),
    ).thenAnswer((_) async => const Right(null));

    // act
    final result = await usecase(tTodoId, tIsCompleted);

    // assert
    expect(result, const Right(null));
    verify(() => mockRepo.toggleTodoStatus(tTodoId, tIsCompleted));
    verifyNoMoreInteractions(mockRepo);
  });
}
