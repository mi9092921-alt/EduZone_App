import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/downloads/presentation/screens/offline_player_screen.dart';
import 'package:app/shared/models/download_enums.dart';
import 'package:app/shared/models/downloaded_lesson.dart';
import 'package:app/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// NOTE ON SCOPE: this file intentionally does NOT exercise the branch that
// renders OfflinePlayerWrapper (the DownloadStatus.completed / found case).
// That widget owns real decryption/player lifecycle logic against the
// encrypted container format described in
// EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md and
// deserves its own dedicated, carefully-scoped test rather than a
// generic screen smoke test built on guessed internals — see
// integration_test/README_TEST_GAPS.md, "downloads + offline access".
// Everything below this screen can independently return WITHOUT reaching
// that widget (not-found / not-ready / loading / error) is covered here.

const _downloadId = 'dl-1';

DownloadedLesson _download({required DownloadStatus status}) {
  return DownloadedLesson(
    id: _downloadId,
    lessonId: 'lesson-1',
    courseId: 'course-1',
    courseTitle: 'Flutter for Beginners',
    title: 'Lesson One',
    localPath: '/tmp/lesson-1',
    encryptedPath: '/tmp/lesson-1.enc',
    videoUrl: 'https://example.com/video.mp4',
    quality: VideoQuality.p720,
    fileSize: 1000,
    status: status,
    downloadedAt: DateTime(2024),
    expiresAt: DateTime(2099),
  );
}

Future<void> pumpOfflinePlayer(
  WidgetTester tester, {
  required List<Override> overrides,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OfflinePlayerScreen(downloadId: _downloadId),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a skeleton while the download record is loading', (
    tester,
  ) async {
    // Audit P1 (M2): the page-level spinner was replaced with a
    // skeletonizer placeholder per the design-system loading rule.
    await pumpOfflinePlayer(
      tester,
      overrides: [
        downloadByIdProvider(_downloadId).overrideWith(
          (ref) => Completer<DownloadedLesson?>().future,
        ),
      ],
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'shows a generic, localized error instead of a raw exception when the '
      'download lookup fails', (tester) async {
    await pumpOfflinePlayer(
      tester,
      overrides: [
        downloadByIdProvider(_downloadId)
            .overrideWith((ref) async => throw Exception('db unavailable')),
      ],
    );
    await tester.pumpAndSettle();

    // Phase 8: the error branch now classifies via ErrorHandler.getMessage
    // (same message family as every other screen); an unknown exception
    // still resolves to the localized generic string. Either way nothing
    // raw ever reaches the screen — and a Retry affordance is present.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.errorGeneric), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets(
      'shows "download not found" when no record exists for the id '
      '(e.g. it was deleted/expired between navigation and load)',
      (tester) async {
    await pumpOfflinePlayer(
      tester,
      overrides: [
        downloadByIdProvider(_downloadId).overrideWith((ref) async => null),
      ],
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.downloadNotFound), findsOneWidget);
  });

  testWidgets(
      'shows "download not ready" instead of attempting playback for a '
      'download that has not reached DownloadStatus.completed',
      (tester) async {
    await pumpOfflinePlayer(
      tester,
      overrides: [
        downloadByIdProvider(_downloadId).overrideWith(
          (ref) async => _download(status: DownloadStatus.downloading),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.downloadNotReady), findsOneWidget);
    expect(find.text('Lesson One'), findsOneWidget); // AppBar title
    // Must NOT attempt to mount the real decrypt/play widget for a
    // not-yet-complete download — this is the security-relevant assertion
    // for this test (playback must be gated on completed status).
    expect(find.text(l10n.offlineModeLabel), findsNothing);
  });

  testWidgets('a failed download also shows "not ready", not a crash', (
    tester,
  ) async {
    await pumpOfflinePlayer(
      tester,
      overrides: [
        downloadByIdProvider(_downloadId).overrideWith(
          (ref) async => _download(status: DownloadStatus.failed),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.downloadNotReady), findsOneWidget);
  });
}
