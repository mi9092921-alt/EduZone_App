import 'dart:async';
import 'dart:io';

import 'package:app/shared/utils/global_error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('GlobalErrorHandler.isConnectivityNoise (GLOBALERRORHANDLER-BUG-01)', () {
    // Production incident: Supabase's own internal background token
    // auto-refresh timer (GoTrueClient._callRefreshToken) fails with a
    // DNS/socket-level error while the device has no connectivity. That
    // failure is never caught by app code, so it reaches
    // PlatformDispatcher.instance.onError -> GlobalErrorHandler.logError
    // as a raw AuthRetryableFetchException(statusCode: null) wrapping a
    // "Failed host lookup" SocketException -- the exact shape seen in the
    // incident. It must be classified as non-actionable connectivity
    // noise, mirroring the fix already applied to
    // CheckStudentAppAccessService._check() for the equivalent case.
    test('classifies a raw SocketException (DNS failure) as noise', () {
      expect(
        GlobalErrorHandler.isConnectivityNoise(
          const SocketException(
            "Failed host lookup: 'evmrahlzcgqgjhwvxzih.supabase.co'",
          ),
        ),
        isTrue,
      );
    });

    test(
        'classifies AuthRetryableFetchException with null statusCode '
        '(GoTrue refresh-timer DNS failure) as noise', () {
      expect(
        GlobalErrorHandler.isConnectivityNoise(
          AuthRetryableFetchException(
            message: 'ClientException with SocketException: '
                "Failed host lookup: 'evmrahlzcgqgjhwvxzih.supabase.co'",
          ),
        ),
        isTrue,
      );
    });

    test('classifies a TimeoutException as noise', () {
      expect(
        GlobalErrorHandler.isConnectivityNoise(
          TimeoutException('deadline exceeded'),
        ),
        isTrue,
      );
    });

    test(
        'does NOT classify AuthRetryableFetchException with a real '
        'statusCode (server-side failure, not connectivity) as noise', () {
      expect(
        GlobalErrorHandler.isConnectivityNoise(
          AuthRetryableFetchException(message: 'bad gateway', statusCode: '502'),
        ),
        isFalse,
      );
    });

    test('does NOT classify an unrelated application exception as noise', () {
      expect(
        GlobalErrorHandler.isConnectivityNoise(StateError('bad widget state')),
        isFalse,
      );
    });
  });

  group('GlobalErrorHandler.logError', () {
    test('does not throw for a plain exception with no stack trace', () {
      expect(
        () => GlobalErrorHandler.logError(Exception('boom'), null),
        returnsNormally,
      );
    });

    test('does not throw when a stack trace is provided', () {
      expect(
        () => GlobalErrorHandler.logError(Exception('boom'), StackTrace.current),
        returnsNormally,
      );
    });

    test('prints the error message to the debug console', () {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      try {
        GlobalErrorHandler.logError(Exception('unique-marker-42'), null);
        expect(logs.any((line) => line.contains('unique-marker-42')), isTrue);
      } finally {
        debugPrint = originalDebugPrint;
      }
    });

    test(
        'flags a connectivity failure in the console output instead of '
        'silently dropping it', () {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      try {
        GlobalErrorHandler.logError(
          const SocketException('Failed host lookup'),
          null,
        );
        expect(
          logs.any((line) => line.contains('not reported to Sentry')),
          isTrue,
        );
      } finally {
        debugPrint = originalDebugPrint;
      }
    });

    test('does not throw for a connectivity failure with no stack trace', () {
      expect(
        () => GlobalErrorHandler.logError(
          const SocketException('Failed host lookup'),
          null,
        ),
        returnsNormally,
      );
    });
  });

  group('GlobalErrorHandler.init', () {
    test('registers FlutterError.onError and PlatformDispatcher.onError handlers', () {
      final originalFlutterOnError = FlutterError.onError;
      final originalPlatformOnError = PlatformDispatcher.instance.onError;

      addTearDown(() {
        FlutterError.onError = originalFlutterOnError;
        PlatformDispatcher.instance.onError = originalPlatformOnError;
      });

      GlobalErrorHandler.init();

      expect(FlutterError.onError, isNotNull);
      expect(PlatformDispatcher.instance.onError, isNotNull);
    });
  });

  group('AppProductionErrorScreen', () {
    testWidgets('renders the friendly Arabic fallback title and message', (tester) async {
      final details = FlutterErrorDetails(exception: Exception('layout crashed'));

      await tester.pumpWidget(AppProductionErrorScreen(details: details));

      expect(find.text('حدث خطأ غير متوقع'), findsOneWidget);
      expect(find.byIcon(Icons.monitor_heart_rounded), findsOneWidget);
    });

    testWidgets('shows raw exception details in debug mode', (tester) async {
      final details = FlutterErrorDetails(exception: Exception('unique-debug-marker'));

      await tester.pumpWidget(AppProductionErrorScreen(details: details));

      // kDebugMode is true under `flutter test`, so the debug panel renders.
      expect(find.textContaining('unique-debug-marker'), findsOneWidget);
    });
  });
}