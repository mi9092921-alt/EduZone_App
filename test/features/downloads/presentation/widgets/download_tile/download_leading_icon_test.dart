import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/presentation/widgets/download_tile/download_leading_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestable(DownloadStatus status) {
    return MaterialApp(
      home: Scaffold(body: DownloadLeadingIcon(status: status)),
    );
  }

  testWidgets('completed shows a play icon', (tester) async {
    await tester.pumpWidget(buildTestable(DownloadStatus.completed));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('downloading shows a progress indicator, not a static icon', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestable(DownloadStatus.downloading));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('paused shows a pause icon', (tester) async {
    await tester.pumpWidget(buildTestable(DownloadStatus.paused));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('failed shows an error icon', (tester) async {
    await tester.pumpWidget(buildTestable(DownloadStatus.failed));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('pending shows a schedule icon', (tester) async {
    await tester.pumpWidget(buildTestable(DownloadStatus.pending));
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  });

  testWidgets('every status renders exactly one icon-bearing container without throwing', (
    tester,
  ) async {
    for (final status in DownloadStatus.values) {
      await tester.pumpWidget(buildTestable(status));
      expect(tester.takeException(), isNull, reason: 'status: $status');
      expect(find.byType(Container), findsOneWidget, reason: 'status: $status');
    }
  });
}
