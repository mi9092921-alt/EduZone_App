import 'package:app/design_system/design_system.dart';
import 'package:app/shared/widgets/app_course_thumbnail.dart';
import 'package:app/shared/widgets/app_network_image.dart';
import 'package:app/shared/widgets/app_thumbnail_fallback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // AppCourseThumbnail requires a DesignSystemColors instance; resolve it
  // from the themed context the same way production screens do.
  Widget harness(String? thumbnailUrl) => MaterialApp(
        theme: AppTheme.light(const Locale('en')),
        home: Scaffold(
          body: Builder(
            builder: (context) => AppCourseThumbnail(
              thumbnailUrl: thumbnailUrl,
              ds: AppColors.of(context),
            ),
          ),
        ),
      );

  testWidgets('renders AppNetworkImage when a thumbnail URL exists', (
    tester,
  ) async {
    await tester.pumpWidget(harness('https://example.com/t.png'));
    await tester.pump();
    expect(find.byType(AppNetworkImage), findsOneWidget);
  });

  testWidgets('falls back to AppThumbnailFallback when URL is null', (
    tester,
  ) async {
    await tester.pumpWidget(harness(null));
    await tester.pump();
    expect(find.byType(AppThumbnailFallback), findsOneWidget);
  });

  testWidgets('falls back to AppThumbnailFallback when URL is empty', (
    tester,
  ) async {
    await tester.pumpWidget(harness(''));
    await tester.pump();
    expect(find.byType(AppThumbnailFallback), findsOneWidget);
  });
}
