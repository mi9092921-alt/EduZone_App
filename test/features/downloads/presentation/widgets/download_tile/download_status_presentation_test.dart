import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/presentation/widgets/download_tile/download_status_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DownloadStatusPresentation.icon', () {
    test('maps each status to a distinct icon', () {
      final icons = DownloadStatus.values
          .map(DownloadStatusPresentation.icon)
          .toSet();
      // 5 statuses -> 5 distinct icons (no accidental fallthrough).
      expect(icons.length, DownloadStatus.values.length);
    });

    test('pending maps to the schedule icon', () {
      expect(
        DownloadStatusPresentation.icon(DownloadStatus.pending),
        Icons.schedule,
      );
    });

    test('completed maps to the check_circle icon', () {
      expect(
        DownloadStatusPresentation.icon(DownloadStatus.completed),
        Icons.check_circle,
      );
    });
  });

  group('DownloadStatusPresentation.color / text (need BuildContext/l10n)', () {
    Widget buildTestable({required Widget Function(BuildContext) builder}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: builder),
      );
    }

    testWidgets('failed status resolves to the design-system error color', (
      tester,
    ) async {
      late Color resolved;
      await tester.pumpWidget(
        buildTestable(
          builder: (context) {
            resolved = DownloadStatusPresentation.color(
              DownloadStatus.failed,
              AppColors.of(context),
            );
            return const SizedBox();
          },
        ),
      );

      expect(resolved, AppColors.of(tester.element(find.byType(SizedBox))).error);
    });

    testWidgets('paused status resolves to the warning color (not theme-dependent)', (
      tester,
    ) async {
      late Color resolved;
      await tester.pumpWidget(
        buildTestable(
          builder: (context) {
            resolved = DownloadStatusPresentation.color(
              DownloadStatus.paused,
              AppColors.of(context),
            );
            return const SizedBox();
          },
        ),
      );

      expect(resolved, AppColors.warning);
    });

    testWidgets('text() returns a non-empty localized label for every status', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            for (final status in DownloadStatus.values) {
              final label = DownloadStatusPresentation.text(status, l10n);
              expect(label, isNotEmpty, reason: 'status: $status');
            }
            return const SizedBox();
          },
        ),
      );
    });
  });

  group('formatDownloadExpiration', () {
    Widget buildTestable({required Widget Function(BuildContext) builder}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: builder),
      );
    }

    final now = DateTime(2026, 1, 1, 12);

    testWidgets('a past expiresAt returns the "expired" copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            final result = formatDownloadExpiration(
              now.subtract(const Duration(hours: 1)),
              l10n,
              now: now,
            );
            expect(result, l10n.downloadExpired);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('more than 30 days away returns the "never expires" copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            final result = formatDownloadExpiration(
              now.add(const Duration(days: 45)),
              l10n,
              now: now,
            );
            expect(result, l10n.downloadNeverExpires);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('a few days away returns the days-remaining copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            final result = formatDownloadExpiration(
              now.add(const Duration(days: 5)),
              l10n,
              now: now,
            );
            expect(result, l10n.downloadExpiresInDays(5));
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('a few hours away returns the hours-remaining copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            final result = formatDownloadExpiration(
              now.add(const Duration(hours: 3)),
              l10n,
              now: now,
            );
            expect(result, l10n.downloadExpiresInHours(3));
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('less than an hour away returns the "expires soon" copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            final result = formatDownloadExpiration(
              now.add(const Duration(minutes: 30)),
              l10n,
              now: now,
            );
            expect(result, l10n.downloadExpiresSoon);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('defaults `now` to DateTime.now() when not supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            final result = formatDownloadExpiration(
              DateTime.now().add(const Duration(days: 60)),
              l10n,
            );
            expect(result, l10n.downloadNeverExpires);
            return const SizedBox();
          },
        ),
      );
    });
  });
}
