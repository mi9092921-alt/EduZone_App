import 'dart:async';
import 'dart:convert';

import 'package:app/core/error/exceptions.dart';
import 'package:app/features/auth/data/datasources/update_remote_ds.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_supabase_http_client.dart';

/// Contract tests for [UpdateRemoteDataSource.fetchConfig].
///
/// A real [SupabaseClient] over a [FakeHttpClient] exercises the actual
/// PostgREST machinery offline (same pattern as
/// `notifications_remote_ds_test.dart`). This call is the FIRST request of
/// every cold start (`Auth._initializeSession`), so its response shape is
/// what `UpdateService.checkForUpdate()` parses.
void main() {
  UpdateRemoteDataSource buildDataSource(
    FutureOr<http.Response> Function(http.BaseRequest request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: FakeHttpClient(handler),
    );
    return UpdateRemoteDataSource(client);
  }

  test('reads only the update-management keys and returns a flat map',
      () async {
    http.BaseRequest? captured;
    final dataSource = buildDataSource((request) async {
      captured = request;
      return http.Response(
        jsonEncode([
          {'key': 'latest_version', 'value': '2.4.0'},
          {'key': 'min_app_version', 'value': '1.0.0'},
          {'key': 'force_update', 'value': false},
          {'key': 'update_message', 'value': 'Please update'},
          {'key': 'store_link_android', 'value': 'https://play.example.com'},
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final config = await dataSource.fetchConfig();

    expect(config['latest_version'], '2.4.0');
    expect(config['min_app_version'], '1.0.0');
    // JSONB booleans arrive as Dart bools, NOT quoted strings.
    expect(config['force_update'], isFalse);
    expect(config['update_message'], 'Please update');
    expect(config['store_link_android'], 'https://play.example.com');
    expect(captured!.url.path, endsWith('/rest/v1/settings_kv'));
    expect(
      captured!.url.queryParameters['key'],
      'in.("latest_version","min_app_version","force_update","update_message","store_link_android","store_link_ios","support_link")',
    );
  });

  test('unwraps quoted JSONB string values', () async {
    final dataSource = buildDataSource(
      (_) async => http.Response(
        jsonEncode([
          {'key': 'latest_version', 'value': '"3.0.0"'},
          {'key': 'support_link', 'value': '  https://help.example.com  '},
        ]),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final config = await dataSource.fetchConfig();

    expect(config['latest_version'], '3.0.0');
    expect(config['support_link'], 'https://help.example.com');
  });

  test('returns an empty map when the table has no rows', () async {
    final dataSource = buildDataSource(
      (_) async => http.Response(
        jsonEncode([]),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    expect(await dataSource.fetchConfig(), isEmpty);
  });

  test('rethrows a PostgrestException as a ServerException preserving the '
      'Postgres error code', () async {
    final dataSource = buildDataSource(
      (_) async => http.Response(
        jsonEncode({
          'message': 'permission denied for table settings_kv',
          'code': '42501',
        }),
        400,
        headers: {'content-type': 'application/json'},
      ),
    );

    await expectLater(
      () => dataSource.fetchConfig(),
      throwsA(
        isA<ServerException>()
            .having(
              (e) => e.message,
              'message',
              'permission denied for table settings_kv',
            )
            .having((e) => e.code, 'code', '42501'),
      ),
    );
  });

  test('escalates an AUTH_REQUIRED rejection to SessionRevokedException via '
      'NetworkGuard', () async {
    // A revoked session surfacing from this (non-auth) RPC must trip the
    // forced sign-out hook through the mapper instead of collapsing into
    // an ordinary ServerException — same contract as every other
    // datasource call that escapes to NetworkGuard.
    final dataSource = buildDataSource(
      (_) async => http.Response(
        jsonEncode({'message': 'AUTH_REQUIRED', 'code': 'P0001'}),
        400,
        headers: {'content-type': 'application/json'},
      ),
    );

    await expectLater(
      () => dataSource.fetchConfig(),
      throwsA(isA<SessionRevokedException>()),
    );
  });
}
