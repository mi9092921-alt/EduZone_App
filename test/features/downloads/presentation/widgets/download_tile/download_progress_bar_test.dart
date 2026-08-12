import 'dart:async';

import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/domain/entities/download_progress.dart';
import 'package:app/features/downloads/domain/repositories/download_repository.dart';
import 'package:app/features/downloads/presentation/providers/downloads_provider.dart';
import 'package:app/features/downloads/presentation/widgets/download_tile/download_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadRepository extends Mock implements DownloadRepository {}

void main() {
  group('DownloadProgressBar', () {
    Widget buildTestable(DownloadProgressBar bar) {
      return MaterialApp(home: Scaffold(body: bar));
    }

    testWidgets('shows the rounded percent label', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DownloadProgressBar(progressPercent: 42.7)),
      );

      expect(find.text('43%'), findsOneWidget);
    });

    testWidgets('shows the bytes label only when provided', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadProgressBar(
            progressPercent: 50,
            bytesLabel: '5.0 MB / 10.0 MB',
          ),
        ),
      );
      expect(find.text('5.0 MB / 10.0 MB'), findsOneWidget);

      await tester.pumpWidget(
        buildTestable(const DownloadProgressBar(progressPercent: 50)),
      );
      expect(find.text('5.0 MB / 10.0 MB'), findsNothing);
    });

    testWidgets('is determinate at 0% by default (indeterminateAtZero: false)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(const DownloadProgressBar(progressPercent: 0)),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.0);
    });

    testWidgets('is indeterminate at 0% when indeterminateAtZero is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadProgressBar(
            progressPercent: 0,
            indeterminateAtZero: true,
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull);
    });

    testWidgets('is still determinate above 0% even with indeterminateAtZero: true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadProgressBar(
            progressPercent: 25,
            indeterminateAtZero: true,
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.25, 0.001));
    });
  });

  group('ActiveDownloadProgress', () {
    late MockDownloadRepository repository;

    setUp(() {
      repository = MockDownloadRepository();
    });

    Widget buildTestable(Widget child) {
      return ProviderScope(
        overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets('renders the fallback (indeterminate) bar while the stream is loading', (
      tester,
    ) async {
      final controller = StreamController<DownloadProgress>();
      addTearDown(controller.close);
      when(() => repository.watchProgress('d1'))
          .thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        buildTestable(
          const ActiveDownloadProgress(
            downloadId: 'd1',
            fallbackProgressPercent: 30,
          ),
        ),
      );

      expect(find.text('30%'), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // fallbackProgressPercent is 30 (> 0) so it's determinate, not indeterminate.
      expect(indicator.value, closeTo(0.3, 0.001));
    });

    testWidgets('switches to the live progress once the stream emits', (
      tester,
    ) async {
      final controller = StreamController<DownloadProgress>();
      addTearDown(controller.close);
      when(() => repository.watchProgress('d1'))
          .thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        buildTestable(
          const ActiveDownloadProgress(
            downloadId: 'd1',
            fallbackProgressPercent: 0,
          ),
        ),
      );

      controller.add(
        const DownloadProgress(
          downloadId: 'd1',
          lessonId: 'l1',
          receivedBytes: 51200,
          totalBytes: 102400,
          progress: 50,
          status: DownloadStatus.downloading,
        ),
      );
      await tester.pump();

      expect(find.text('50%'), findsOneWidget);
      expect(find.textContaining('KB'), findsOneWidget);
    });

    testWidgets('falls back to the indeterminate bar on a stream error', (
      tester,
    ) async {
      final controller = StreamController<DownloadProgress>();
      addTearDown(controller.close);
      when(() => repository.watchProgress('d1'))
          .thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        buildTestable(
          const ActiveDownloadProgress(
            downloadId: 'd1',
            fallbackProgressPercent: 0,
          ),
        ),
      );

      controller.addError(Exception('boom'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull);
    });
  });
}
