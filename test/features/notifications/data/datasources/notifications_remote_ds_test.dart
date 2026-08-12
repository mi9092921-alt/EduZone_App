import 'dart:async';
import 'dart:convert';

import 'package:app/core/error/exceptions.dart';
import 'package:app/features/notifications/data/datasources/notifications_remote_ds.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeHttpClient extends http.BaseClient {
  final FutureOr<http.Response> Function(http.BaseRequest request) handler;

  FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

void main() {
  group('getNotifications', () {
    const userId = 'user123';

    NotificationsRemoteDataSourceImpl buildDataSource(
      FutureOr<http.Response> Function(http.BaseRequest request) handler,
    ) {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: FakeHttpClient(handler),
      );
      return NotificationsRemoteDataSourceImpl(client);
    }

    test('should retrieve notifications and merge details', () async {
      final dataSource = buildDataSource((request) {
        if (request.url.path.endsWith('/user_notifications')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'un_id_1',
                'user_id': userId,
                'notification_id': 'n_id_1',
                'tenant_id': 'tenant_123',
                'is_read': false,
                'read_at': null,
                'created_at': '2026-06-24T12:00:00.000Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.endsWith('/notifications')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'n_id_1',
                'title': 'Test Notification',
                'body': 'This is a test notification body',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not found', 404);
      });

      final result = await dataSource.getNotifications(userId);

      expect(result, isNotEmpty);
      final firstItem = result.first;
      final notification = firstItem['notification'] as Map<String, dynamic>;
      expect(firstItem['id'], 'un_id_1');
      expect(notification['title'], 'Test Notification');
    });

    test('should throw ServerException when select fails', () async {
      final dataSource = buildDataSource((request) {
        return http.Response(
          jsonEncode({'message': 'Database error'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      expect(
        () => dataSource.getNotifications(userId),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
