import 'dart:async';

import 'package:app/core/error/failures.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/domain/repositories/download_repository.dart';
import 'package:app/features/downloads/presentation/widgets/download_tile/download_action_buttons.dart';
import 'package:app/shared/utils/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadRepository extends Mock implements DownloadRepository {}

void main() {
  late MockDownloadRepository repository;
  late StreamController<void> changeStreamController;

  setUp(() {
    repository = MockDownloadRepository();
    changeStreamController = StreamController<void>.broadcast();
    when(() => repository.changeStream)
        .thenAnswer((_) => changeStreamController.stream);
    when(() => repository.getDownloads())
        .thenAnswer((_) async => const Right([]));
  });

  tearDown(() async {
    await changeStreamController.close();
  });

  Widget buildTestable(Widget child) {
    return ProviderScope(
      overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        scaffoldMessengerKey: FeedbackService.messengerKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('DownloadActionButtons — button set per status', () {
    testWidgets('downloading shows a single pause button', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.downloading,
          ),
        ),
      );

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('paused shows resume + cancel buttons', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.paused,
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('completed shows a single delete button', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.completed,
          ),
        ),
      );

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('failed shows retry + delete buttons', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.failed,
          ),
        ),
      );

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('pending shows a single cancel button', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.pending,
          ),
        ),
      );

      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });
  });

  group('DownloadActionButtons — wiring to DownloadsNotifier', () {
    testWidgets('tapping pause calls repository.pauseDownload with the id', (
      tester,
    ) async {
      when(() => repository.pauseDownload('d1'))
          .thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.downloading,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      verify(() => repository.pauseDownload('d1')).called(1);
    });

    testWidgets('a repository failure shows an error SnackBar instead of throwing', (
      tester,
    ) async {
      when(() => repository.pauseDownload('d1')).thenAnswer(
        (_) async => const Left(CacheFailure('disk full')),
      );

      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.downloading,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('completed: delete button opens a confirmation dialog first '
        '(does not call the repository immediately)', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.completed,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      verifyNever(() => repository.deleteDownload(any()));
    });

    testWidgets('confirming the delete dialog calls repository.deleteDownload', (
      tester,
    ) async {
      when(() => repository.deleteDownload('d1'))
          .thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.completed,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // The confirm button's label is the localized "delete" copy — the
      // same one on the AppBar-less AlertDialog's second TextButton.
      final l10nContext = tester.element(find.byType(AlertDialog));
      final l10n = AppLocalizations.of(l10nContext)!;
      await tester.tap(find.text(l10n.downloadsDeleteBtn));
      await tester.pumpAndSettle();

      verify(() => repository.deleteDownload('d1')).called(1);
    });

    testWidgets('cancelling the delete dialog does not call the repository', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          const DownloadActionButtons(
            downloadId: 'd1',
            status: DownloadStatus.completed,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      final l10nContext = tester.element(find.byType(AlertDialog));
      final l10n = AppLocalizations.of(l10nContext)!;
      await tester.tap(find.text(l10n.downloadsCancelBtn));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => repository.deleteDownload(any()));
    });
  });
}
