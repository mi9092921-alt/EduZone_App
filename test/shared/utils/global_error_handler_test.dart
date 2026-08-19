import 'package:app/shared/utils/global_error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
