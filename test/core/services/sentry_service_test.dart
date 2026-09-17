import 'package:app/core/services/sentry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _MockSentryEvent extends Mock implements SentryEvent {}

void main() {
  group('SentryService.redactCredentials', () {
    test('redacts token values in query strings', () {
      const url =
          'GET https://example.supabase.co/storage/v1/object/sign/bucket/'
          'lesson.mp4?token=eyJhbGciOiJIUzI1NiJ9.signed-part&expires=1800';

      final redacted = SentryService.redactCredentials(url);

      expect(redacted, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(redacted, contains('token=***'));
      // Non-credential parameters survive untouched.
      expect(redacted, contains('expires=1800'));
    });

    test('redacts apikey, api_key and key variants case-insensitively', () {
      expect(
        SentryService.redactCredentials('apikey=SUPABASE_ANON_VALUE'),
        contains('apikey=***'),
      );
      expect(
        SentryService.redactCredentials('api_Key=abc123'),
        contains('api_Key=***'),
      );
      expect(
        SentryService.redactCredentials('KEY=abc123'),
        contains('KEY=***'),
      );
    });

    test('redacts Bearer credentials', () {
      const header = 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig';

      final redacted = SentryService.redactCredentials(header);

      expect(redacted, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(redacted, contains('Bearer ***'));
    });

    test('redacts password, secret, signature and authorization params', () {
      expect(
        SentryService.redactCredentials('?password=hunter2&x=1'),
        contains('password=***'),
      );
      expect(
        SentryService.redactCredentials('?secret=abc&x=1'),
        contains('secret=***'),
      );
      expect(
        SentryService.redactCredentials('?signature=deadbeef&x=1'),
        contains('signature=***'),
      );
    });

    test('leaves ordinary text and benign URLs untouched', () {
      const text = 'PostgrestException: relation "todos" not found (404)';
      expect(SentryService.redactCredentials(text), text);

      const url = 'GET https://example.supabase.co/rest/v1/courses?limit=20';
      expect(SentryService.redactCredentials(url), url);
    });
  });

  group('SentryService.redactEvent', () {
    test('redacts exception values, breadcrumb messages and the message', () {
      final event = SentryEvent(
        message: const SentryMessage(
          'GET https://x.supabase.co/rest/v1/todos?token=abc.def.ghi failed',
        ),
        exceptions: const [
          SentryException(
            type: 'ServerException',
            value: 'GET https://x.supabase.co/storage/v1/sign/b/1.mp4'
                '?token=abc.def.ghi → 403',
          ),
        ],
        breadcrumbs: [
          Breadcrumb(
            message: 'GET https://x.supabase.co/rest/v1/rpc/log_open'
                '?apikey=anon-key-value',
          ),
        ],
      );

      final redacted = SentryService.redactEvent(event)!;

      final serialized = redacted.toString() +
          (redacted.exceptions?.map((e) => e.value).join() ?? '') +
          (redacted.breadcrumbs?.map((b) => b.message).join() ?? '') +
          (redacted.message?.formatted ?? '');

      expect(serialized, isNot(contains('abc.def.ghi')));
      expect(serialized, isNot(contains('anon-key-value')));
      expect(redacted.message?.formatted, contains('token=***'));
      expect(redacted.exceptions?.first.value, contains('token=***'));
      expect(redacted.breadcrumbs?.first.message, contains('apikey=***'));
    });

    test('keeps credential-free events intact (values preserved)', () {
      const originalValue = 'SocketException: Failed host lookup';
      final event = SentryEvent(
        exceptions: [
          const SentryException(type: 'SocketException', value: originalValue),
        ],
      );

      final redacted = SentryService.redactEvent(event)!;

      expect(redacted.exceptions?.first.value, originalValue);
    });

    test('drops the event entirely if redaction fails (fail-closed)', () {
      // An event whose exception walk throws mid-redaction must not be
      // forwarded unredacted — redactEvent returns null instead.
      final hostileEvent = _MockSentryEvent();
      when(() => hostileEvent.exceptions).thenThrow(StateError('hostile'));
      expect(SentryService.redactEvent(hostileEvent), isNull);
    });
  });
}
