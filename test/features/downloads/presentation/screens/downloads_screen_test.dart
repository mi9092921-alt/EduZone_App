import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/downloads/domain/repositories/download_repository.dart';
import 'package:app/features/downloads/presentation/screens/downloads_screen.dart';
import 'package:app/shared/models/download_enums.dart';
import 'package:app/shared/models/downloaded_lesson.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/feature_flag_overrides.dart';

class MockDownloadRepository extends Mock implements DownloadRepository {}

void main() {
  group('resolveCourseGroupTitle', () {
    test('uses course title when available', () {
      final download = DownloadedLesson(
        id: '1',
        lessonId: 'lesson-1',
        courseId: 'course-123',
        courseTitle: 'Advanced Physics',
        title: 'Lesson 1',
        localPath: '/tmp/1',
        encryptedPath: '/tmp/1.enc',
        videoUrl: 'https://example.com/video.mp4',
        quality: VideoQuality.p720,
        fileSize: 100,
        status: DownloadStatus.completed,
        downloadedAt: DateTime(2024),
        expiresAt: DateTime(2025),
      );

      expect(resolveCourseGroupTitle(download), 'Advanced Physics');
    });

    test('falls back to course id when title is empty', () {
      final download = DownloadedLesson(
        id: '2',
        lessonId: 'lesson-2',
        courseId: 'course-456',
        title: 'Lesson 2',
        localPath: '/tmp/2',
        encryptedPath: '/tmp/2.enc',
        videoUrl: 'https://example.com/video2.mp4',
        quality: VideoQuality.p720,
        fileSize: 200,
        status: DownloadStatus.completed,
        downloadedAt: DateTime(2024),
        expiresAt: DateTime(2025),
      );

      expect(resolveCourseGroupTitle(download), 'course-456');
    });
  });

  group('DownloadsScreen — downloads kill switch', () {
    late MockDownloadRepository downloadRepository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      downloadRepository = MockDownloadRepository();
      when(() => downloadRepository.getDownloads())
          .thenAnswer((_) async => const Right([]));
      when(() => downloadRepository.changeStream)
          .thenAnswer((_) => const Stream.empty());
    });

    Widget wrap(List<Override> overrides) {
      return ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DownloadsScreen(),
        ),
      );
    }

    testWidgets(
        'renders the manager UI (empty list) by default — unregistered flag '
        'preserves current behavior', (tester) async {
      await tester.pumpWidget(
        wrap([downloadRepositoryProvider.overrideWithValue(downloadRepository)]),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.downloadsTitle), findsOneWidget);
      expect(find.text(l10n.downloadsEmpty), findsOneWidget);
      // Manager-only affordance is offered on the normal path.
      expect(find.byIcon(Icons.cleaning_services), findsOneWidget);
    });

    testWidgets(
        'renders the empty state instead of the manager UI when the flag is '
        'disabled — even if the screen is reached through a stale route', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap([
          downloadRepositoryProvider.overrideWithValue(downloadRepository),
          featureFlagsOverride({FeatureFlagKey.coursesDownloads: false}),
        ]),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.downloadsTitle), findsOneWidget);
      expect(find.text(l10n.downloadsEmpty), findsOneWidget);
      // Manager-only affordances are not offered while kill-switched.
      expect(find.byIcon(Icons.cleaning_services), findsNothing);
    });
  });
}
