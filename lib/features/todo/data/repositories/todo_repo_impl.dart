import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/todo_item.dart';
import '../../domain/repositories/todo_repository.dart';
import '../datasources/todo_remote_ds.dart';

class TodoRepositoryImpl implements TodoRepository {
  final TodoRemoteDataSource remoteDataSource;
  final SupabaseClient? _supabaseClient;

  TodoRepositoryImpl({
    required this.remoteDataSource,
    SupabaseClient? supabaseClient,
  }) : _supabaseClient = supabaseClient;

  SupabaseClient get _client => _supabaseClient ?? SupabaseService.client;

  @override
  Future<Either<Failure, List<TodoItem>>> fetchTodos() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Left(ServerFailure('User not authenticated'));
      }
      final todos = await remoteDataSource.fetchTodos(userId);
      return Right(todos);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> toggleTodoStatus(
    String todoId,
    bool isCompleted,
  ) async {
    try {
      await remoteDataSource.toggleTodoStatus(todoId, isCompleted);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addTodo(TodoItem todo) async {
    try {
      await remoteDataSource.addTodo(todo);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateTodo(TodoItem todo) async {
    try {
      await remoteDataSource.updateTodo(todo);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTodo(String todoId) async {
    try {
      await remoteDataSource.deleteTodo(todoId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
