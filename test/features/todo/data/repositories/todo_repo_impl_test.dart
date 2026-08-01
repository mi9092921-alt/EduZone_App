import 'package:app/core/error/exceptions.dart';
import 'package:app/core/error/failures.dart';
import 'package:app/features/todo/data/datasources/todo_remote_ds.dart';
import 'package:app/features/todo/data/repositories/todo_repo_impl.dart';
import 'package:app/features/todo/domain/entities/todo_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockTodoRemoteDataSource extends Mock implements TodoRemoteDataSource {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class FakeTodoItem extends Fake implements TodoItem {}

void main() {
  late TodoRepositoryImpl repository;
  late MockTodoRemoteDataSource mockRemoteDataSource;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUpAll(() {
    registerFallbackValue(FakeTodoItem());
  });

  setUp(() {
    mockRemoteDataSource = MockTodoRemoteDataSource();
    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    repository = TodoRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      supabaseClient: mockSupabaseClient,
    );

    when(() => mockSupabaseClient.auth).thenReturn(mockAuth);
  });

  const tTodo = TodoItem(
    id: '1',
    userId: 'u1',
    tenantId: 't1',
    title: 'Test',
  );

  final tTodoList = [tTodo];
  const tUserId = 'u1';

  group('fetchTodos', () {
    test(
      'should return Right(List<TodoItem>) when user is authenticated and call is successful',
      () async {
        // arrange
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.id).thenReturn(tUserId);
        when(
          () => mockRemoteDataSource.fetchTodos(tUserId),
        ).thenAnswer((_) async => tTodoList);

        // act
        final result = await repository.fetchTodos();

        // assert
        expect(result, equals(Right(tTodoList)));
        verify(() => mockRemoteDataSource.fetchTodos(tUserId)).called(1);
      },
    );

    test(
      'should return Left(ServerFailure) when user is not authenticated',
      () async {
        // arrange
        when(() => mockAuth.currentUser).thenReturn(null);

        // act
        final result = await repository.fetchTodos();

        // assert
        expect(
          result,
          equals(
            const Left<Failure, List<TodoItem>>(
              ServerFailure('User not authenticated'),
            ),
          ),
        );
        verifyZeroInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return Left(ServerFailure) when data source throws ServerException',
      () async {
        // arrange
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.id).thenReturn(tUserId);
        when(
          () => mockRemoteDataSource.fetchTodos(tUserId),
        ).thenThrow(const ServerException('DB Error'));

        // act
        final result = await repository.fetchTodos();

        // assert
        expect(
          result,
          equals(
            const Left<Failure, List<TodoItem>>(ServerFailure('DB Error')),
          ),
        );
      },
    );
  });

  group('addTodo', () {
    test('should return Right(null) when call is successful', () async {
      // arrange
      when(
        () => mockRemoteDataSource.addTodo(any()),
      ).thenAnswer((_) async => {});

      // act
      final result = await repository.addTodo(tTodo);

      // assert
      expect(result, equals(const Right(null)));
      verify(() => mockRemoteDataSource.addTodo(tTodo)).called(1);
    });
  });

  group('updateTodo', () {
    test('should return Right(null) when call is successful', () async {
      // arrange
      when(
        () => mockRemoteDataSource.updateTodo(any()),
      ).thenAnswer((_) async => {});

      // act
      final result = await repository.updateTodo(tTodo);

      // assert
      expect(result, equals(const Right(null)));
      verify(() => mockRemoteDataSource.updateTodo(tTodo)).called(1);
    });
  });

  group('deleteTodo', () {
    test('should return Right(null) when call is successful', () async {
      // arrange
      when(
        () => mockRemoteDataSource.deleteTodo(any()),
      ).thenAnswer((_) async => {});

      // act
      final result = await repository.deleteTodo('1');

      // assert
      expect(result, equals(const Right(null)));
      verify(() => mockRemoteDataSource.deleteTodo('1')).called(1);
    });
  });
}
