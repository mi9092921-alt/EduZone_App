import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

/// Offline stand-in for the HTTP transport under a real `SupabaseClient`.
///
/// Mirrors the `FakeHttpClient` pattern already established in
/// `test/features/notifications/data/datasources/notifications_remote_ds_test.dart`:
/// a `SupabaseClient(url, anonKey, httpClient: FakeHttpClient(handler))`
/// exercises the REAL Postgrest/GoTrue/Storage request-building machinery
/// (URLs, headers, body encoding, response parsing, `PostgrestException`
/// raising) while every byte stays in-process — no network, no platform
/// channels. Handlers route by `request.url` and return canned
/// [http.Response]s, e.g. a PostgREST error:
///
/// ```dart
/// http.Response(
///   jsonEncode({'message': 'AUTH_REQUIRED', 'code': 'P0001'}),
///   400,
///   headers: {'content-type': 'application/json'},
/// )
/// ```
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
