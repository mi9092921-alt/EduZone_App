import 'dart:async';
import 'dart:convert';

import 'package:app/core/error/exceptions.dart';
import 'package:app/features/todo/data/datasources/todo_remote_ds_impl.dart';
import 'package:app/shared/models/todo_item.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_supabase_http_client.dart';

/// Contract tests for [TodoRemoteDataSourceImpl].
///
/// The datasource takes an injected [SupabaseClient]; a real client is
/// constructed over a [FakeHttpClient] so the actual PostgREST
/// request-building and response-parsing machinery runs while every byte
/// stays in-process (same pattern as `notifications_remote_ds_test.dart`).
void main() {
  final tTodo = TodoItem(
    id: 'todo-1',
    userId: 'u1',
    tenantId: 't1',
    title: 'Study math',
    dueAt: DateTime.parse('2026-09-20T10:00:00.000Z'),
    priority: 2,
    createdAt: DateTime.parse('2026-09-01T08:00:00.000Z'),
    updatedAt: DateTime.parse('2026-09-01T08:00:00.000Z'),
  );

  const tTodoRow = {
    'id': 'todo-1',
    'user_id': 'u1',
    'tenant_id': 't1',
    'title': 'Study math',
    'due_at': '2026-09-20T10:00:00.000Z',
    'is_completed': false,
    'priority': 2,
    'created_at': '2026-09-01T08:00:00.000Z',
    'updated_at': '2026-09-01T08:00:00.000Z',
    'deleted_at': null,
  };

  TodoRemoteDataSourceImpl buildDataSource(
    FutureOr<http.Response> Function(http.BaseRequest request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: FakeHttpClient(handler),
    );
    return TodoRemoteDataSourceImpl(supabaseClient: client);
  }

  group('fetchTodos', () {
    test('queries the todos table scoped to the user with the soft-delete '
        'filter and the documented sort order', () async {
      http.BaseRequest? captured;
      final dataSource = buildDataSource((request) async {
        captured = request;
        return http.Response(
          jsonEncode([tTodoRow]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final todos = await dataSource.fetchTodos('u1');

      expect(todos, hasLength(1));
      expect(todos.single.id, 'todo-1');
      expect(todos.single.title, 'Study math');
      expect(todos.single.isCompleted, isFalse);
      expect(todos.single.dueAt, DateTime.parse('2026-09-20T10:00:00.000Z'));
      expect(captured!.url.path, endsWith('/rest/v1/todos'));
      expect(captured!.url.queryParameters['user_id'], 'eq.u1');
      expect(captured!.url.queryParameters['deleted_at'], 'is.null');
      // Nearest due date first, then highest priority. postgrest 2.9.1
      // emits the two .order() calls as ONE combined `order` param, with
      // its default nulls-last ordering appended to each column.
      expect(
        captured!.url.queryParametersAll['order'],
        ['due_at.asc.nullslast,priority.desc.nullslast'],
      );
    });

    test('returns an empty list when the user has no todos', () async {
      final dataSource = buildDataSource(
        (_) async => http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(await dataSource.fetchTodos('u1'), isEmpty);
    });

    test('maps a PostgrestException (e.g. RLS denial) to a ServerException '
        'that preserves the Postgres error code', () async {
      final dataSource = buildDataSource(
        (_) async => http.Response(
          jsonEncode({'message': 'permission denied for table todos', 'code': '42501'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        () => dataSource.fetchTodos('u1'),
        throwsA(
          isA<ServerException>()
              .having(
                (e) => e.message,
                'message',
                'permission denied for table todos',
              )
              .having((e) => e.code, 'code', '42501'),
        ),
      );
    });
  });

  group('addTodo', () {
    test('inserts the full row with soft-delete fields initialized',
        () async {
      http.Request? captured;
      final dataSource = buildDataSource((request) async {
        captured = request as http.Request;
        return http.Response('', 201);
      });

      await dataSource.addTodo(tTodo);

      expect(captured!.method, 'POST');
      expect(captured!.url.path, endsWith('/rest/v1/todos'));
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['id'], 'todo-1');
      expect(body['user_id'], 'u1');
      expect(body['tenant_id'], 't1');
      expect(body['title'], 'Study math');
      expect(body['priority'], 2);
      expect(body['is_completed'], false);
      expect(body['deleted_at'], isNull);
      expect(body['due_at'], '2026-09-20T10:00:00.000Z');
    });

    test('surfaces an insert failure as a ServerException', () async {
      final dataSource = buildDataSource(
        (_) async => http.Response(
          jsonEncode({'message': 'duplicate key value', 'code': '23505'}),
          409,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        () => dataSource.addTodo(tTodo),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            '23505',
          ),
        ),
      );
    });
  });

  group('toggleTodoStatus', () {
    test('patches only the is_completed column for the given id', () async {
      http.Request? captured;
      final dataSource = buildDataSource((request) async {
        captured = request as http.Request;
        return http.Response('', 204);
      });

      await dataSource.toggleTodoStatus('todo-1', true);

      expect(captured!.method, 'PATCH');
      expect(captured!.url.path, endsWith('/rest/v1/todos'));
      expect(captured!.url.queryParameters['id'], 'eq.todo-1');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body, {'is_completed': true});
    });
  });

  group('updateTodo', () {
    test('patches the editable fields but never updated_at (handled by the '
        'trg_todos_updated_at trigger)', () async {
      http.Request? captured;
      final dataSource = buildDataSource((request) async {
        captured = request as http.Request;
        return http.Response('', 204);
      });

      await dataSource.updateTodo(tTodo);

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['title'], 'Study math');
      expect(body['due_at'], '2026-09-20T10:00:00.000Z');
      expect(body['priority'], 2);
      expect(body['is_completed'], false);
      expect(body.containsKey('updated_at'), isFalse);
    });
  });

  group('deleteTodo', () {
    test('soft-deletes by stamping deleted_at on a live row', () async {
      http.Request? captured;
      final dataSource = buildDataSource((request) async {
        captured = request as http.Request;
        return http.Response('', 204);
      });

      await dataSource.deleteTodo('todo-1');

      expect(captured!.method, 'PATCH');
      expect(captured!.url.queryParameters['id'], 'eq.todo-1');
      // Only rows not already deleted are targeted.
      expect(captured!.url.queryParameters['deleted_at'], 'is.null');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      final deletedAt = body['deleted_at'] as String?;
      expect(deletedAt, isNotNull);
      expect(deletedAt, endsWith('Z'));
    });

    test('maps a PostgrestException on the soft delete to a ServerException',
        () async {
      final dataSource = buildDataSource(
        (_) async => http.Response(
          jsonEncode({'message': 'AUTH_REQUIRED', 'code': 'P0001'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );

      // The mapper escalates the server's AUTH_REQUIRED signature to a
      // session-revocation exception (fires SessionRevocationHook) — a
      // revoked session must force sign-out, not look like a todo error.
      await expectLater(
        () => dataSource.deleteTodo('todo-1'),
        throwsA(isA<SessionRevokedException>()),
      );
    });
  });
}
