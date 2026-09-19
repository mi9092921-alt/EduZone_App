import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/core/error/exceptions.dart';
import 'package:app/features/profile/data/datasources/profile_remote_ds.dart';
import 'package:app/shared/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_supabase_http_client.dart';

/// Contract tests for [ProfileRemoteDataSource] against the REAL
/// Supabase request machinery, kept offline by routing every HTTP call
/// through a [FakeHttpClient] (same pattern as
/// `notifications_remote_ds_test.dart`).
///
/// `ProfileRemoteDataSource` reaches Supabase through the static
/// `SupabaseService.client` (no injected client), so this file must
/// `Supabase.initialize(...)` once with the offline HTTP client. The
/// profile datasource is therefore initialized only here; every request it
/// makes is matched by a handler in the per-test `handler` variable.
void main() {
  late ProfileRemoteDataSource dataSource;

  /// Per-test HTTP router; defaults to an empty JSON array so an
  /// unexpected request fails loudly (as a Postgrest error) instead of
  /// silently succeeding.
  FutureOr<http.Response> Function(http.BaseRequest request) handler =
      (_) => http.Response('[]', 500, headers: {'content-type': 'application/json'});

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Supabase.initialize wires a SharedPreferences-backed PKCE async
    // storage whose eager initialization must not hit a missing plugin
    // channel — mock it before initialize.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fake-project.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: FakeHttpClient((request) => handler(request)),
      // In-memory session only: no SharedPreferences-backed session
      // persistence, so the singleton starts signed-out for every test.
      authOptions: const FlutterAuthClientOptions(persistSession: false),
    );
    dataSource = ProfileRemoteDataSource();
  });

  /// Builds an unsigned (not cryptographically valid — signature isn't
  /// checked client-side) JWT with a far-future expiry, matching how
  /// `GoTrueClient.setSession` validates tokens.
  String buildJwt() {
    String encode(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final header = encode({'alg': 'none', 'typ': 'JWT'});
    final body = encode({
      'sub': 'user-1',
      'iat': 1000000000,
      'exp': 9999999999,
    });
    return '$header.$body.';
  }

  /// Establishes an in-memory authenticated session so
  /// `SupabaseService.client.auth.currentUser!` succeeds. The
  /// `/auth/v1/user` lookup setSession performs is served offline by the
  /// fake HTTP client.
  Future<void> signInAsStudent() async {
    final previousHandler = handler;
    handler = (request) {
      if (request.url.path.endsWith('/auth/v1/user')) {
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'aud': 'authenticated',
            'email': 'student@example.com',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return previousHandler(request);
    };
    await Supabase.instance.client.auth.setSession(
      'refresh-token',
      accessToken: buildJwt(),
    );
  }

  const tRow = {
    'id': 'user-1',
    'email': 'student@example.com',
    'first_name': 'Test',
    'last_name': 'Student',
    'tenant_id': 'tenant-1',
    'primary_role': 'student',
    'account_status': 'active',
  };

  group('getProfile', () {
    test('maps the users row into a StudentProfile scoped to the session id',
        () async {
      await signInAsStudent();
      http.BaseRequest? captured;
      handler = (request) async {
        captured = request;
        return http.Response(
          jsonEncode(tRow),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final profile = await dataSource.getProfile();

      expect(profile.id, 'user-1');
      expect(profile.email, 'student@example.com');
      expect(profile.firstName, 'Test');
      expect(profile.lastName, 'Student');
      expect(profile.tenantId, 'tenant-1');
      expect(profile.primaryRole, UserRole.student);
      expect(
        captured!.url.path,
        endsWith('/rest/v1/users'),
      );
      expect(captured!.url.queryParameters['id'], 'eq.user-1');
    });

    test('rethrows a PostgrestException as a ServerException that keeps the '
        'Postgres error code', () async {
      await signInAsStudent();
      handler = (request) => http.Response(
            jsonEncode({'message': 'row-level security violation', 'code': '42501'}),
            400,
            headers: {'content-type': 'application/json'},
          );

      await expectLater(
        () => dataSource.getProfile(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'row-level security violation')
              .having((e) => e.code, 'code', '42501'),
        ),
      );
    });
  });

  group('updateProfile', () {
    test('with no parameters short-circuits to getProfile without calling '
        'the api_update_profile RPC', () async {
      await signInAsStudent();
      var rpcCalled = false;
      handler = (request) {
        if (request.url.path.endsWith('/rpc/api_update_profile')) {
          rpcCalled = true;
        }
        return http.Response(
          jsonEncode(tRow),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final profile = await dataSource.updateProfile();

      expect(profile.email, 'student@example.com');
      expect(rpcCalled, isFalse);
    });

    test('calls api_update_profile with only the non-null params, then '
        're-reads the row', () async {
      await signInAsStudent();
      final rpcBodies = <Map<String, dynamic>>[];
      handler = (request) async {
        if (request.url.path.endsWith('/rpc/api_update_profile')) {
          final body = (request as http.Request).body;
          rpcBodies.add(jsonDecode(body) as Map<String, dynamic>);
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/rest/v1/users')) {
          return http.Response(
            jsonEncode({
              ...tRow,
              'first_name': 'Nova',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'message': 'unexpected request', 'code': 'TEST404'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      };

      // The UpdateProfile USECASE trims before delegating, so the
      // datasource receives pre-trimmed values and forwards them verbatim
      // (it must not re-transform its input).
      final profile = await dataSource.updateProfile(firstName: 'Nova');

      expect(profile.firstName, 'Nova');
      expect(rpcBodies.single['p_first_name'], 'Nova');
      // Null-aware map entry: an unchanged last name must not be sent at
      // all, so the RPC can leave the column untouched.
      expect(rpcBodies.single.containsKey('p_last_name'), isFalse);
    });

    test('escalates an AUTH_REQUIRED RPC rejection to '
        'SessionRevokedException via NetworkGuard', () async {
      // SECURITY CONTRACT: the server kills the session by raising
      // AUTH_REQUIRED from the SECURITY DEFINER RPC; the datasource
      // pre-converts the PostgrestException to a ServerException, and
      // NetworkGuard's mapper must recognize the revocation signature and
      // fire SessionRevocationHook instead of surfacing an ordinary
      // business error.
      await signInAsStudent();
      handler = (request) async {
        if (request.url.path.endsWith('/rpc/api_update_profile')) {
          return http.Response(
            jsonEncode({'message': 'AUTH_REQUIRED', 'code': 'P0001'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(tRow),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      await expectLater(
        () => dataSource.updateProfile(firstName: 'Nova'),
        throwsA(isA<SessionRevokedException>()),
      );
    });
  });

  group('uploadAvatar', () {
    late Directory tempDir;
    late File imageFile;

    setUp(() async {
      await signInAsStudent();
      tempDir = await Directory.systemTemp.createTemp('profile_ds_test');
      imageFile = File('${tempDir.path}/avatar.png');
      await imageFile.writeAsBytes(List<int>.filled(4, 0xFF));
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('uploads the file with the derived MIME type, persists the public '
        'URL via the RPC, and returns the cache-busted URL', () async {
      final uploads = <http.BaseRequest>[];
      handler = (request) async {
        if (request.url.path.endsWith('/storage/v1/object/avatars/user-1/avatar.png')) {
          uploads.add(request);
          return http.Response(
            jsonEncode({'Key': 'avatars/user-1/avatar.png'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/rpc/api_update_profile')) {
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode({'message': 'unexpected request', 'code': 'TEST404'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      };

      final url = await dataSource.uploadAvatar(imageFile.path);

      expect(uploads, hasLength(1));
      // storage_client 2.8.0 passes FileOptions.contentType as the
      // MULTIPART PART's media type, not a request header — assert it in
      // the encoded multipart body instead of the request headers.
      // The multipart FILE PART carries the derived media type.
      final filePart = (uploads.single as http.MultipartRequest).files.single;
      expect(filePart.contentType.mimeType, 'image/png');
      // Public URL plus a cache-busting timestamp so the fresh avatar is
      // fetched immediately instead of served from a stale CDN cache.
      expect(
        url,
        contains('/object/public/avatars/user-1/avatar.png?t='),
      );
      expect(url.split('?t=').last, isNotEmpty);
    });

    test('maps a StorageException (e.g. blocked RLS on the upsert SELECT) '
        'to a ServerException', () async {
      // AVATAR-BUG-01 regression shape: without the storage SELECT policy
      // the upload fails even on a public bucket.
      handler = (request) => http.Response(
            jsonEncode({
              'message': 'new row violates row-level security policy',
              'error': '42501',
            }),
            403,
            headers: {'content-type': 'application/json'},
          );

      await expectLater(
        () => dataSource.uploadAvatar(imageFile.path),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('row-level security'),
          ),
        ),
      );
    });
  });
}
