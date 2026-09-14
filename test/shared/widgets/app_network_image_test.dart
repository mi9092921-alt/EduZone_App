import 'package:app/core/cache/app_image_cache_manager.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/shared/widgets/app_network_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests never perform real network I/O (AGENTS testing rules), so
/// these tests assert AppNetworkImage's *configuration contract* — the
/// decode-bounding and shared-cache wiring the widget adds on top of
/// CachedNetworkImage — rather than the plugin's own load/error branches.
void main() {
  Widget harness(Widget child) => MaterialApp(
        theme: AppTheme.light(const Locale('en')),
        home: Scaffold(body: child),
      );

  Future<CachedNetworkImage> pumpAndRead(
    WidgetTester tester,
    Widget child,
  ) async {
    await tester.pumpWidget(harness(child));
    await tester.pump();
    return tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
  }

  testWidgets('bounds decode to the target box scaled by device DPR', (
    tester,
  ) async {
    // Widget tests run at a default devicePixelRatio of 3.0.
    final image = await pumpAndRead(
      tester,
      const AppNetworkImage(
        url: 'https://example.com/a.png',
        width: 60,
        height: 60,
      ),
    );

    expect(image.width, 60);
    expect(image.height, 60);
    expect(image.memCacheWidth, 180); // 60 * 3.0, rounded
    expect(image.memCacheHeight, 180);
    expect(image.fit, BoxFit.cover);
    expect(image.cacheManager, AppImageCacheManager.instance);
  });

  testWidgets('leaves decode unbounded when no target box is given', (
    tester,
  ) async {
    final image = await pumpAndRead(
      tester,
      const AppNetworkImage(url: 'https://example.com/b.png'),
    );

    expect(image.memCacheWidth, isNull);
    expect(image.memCacheHeight, isNull);
  });

  testWidgets('passes through a non-default fit and alignment', (
    tester,
  ) async {
    final image = await pumpAndRead(
      tester,
      const AppNetworkImage(
        url: 'https://example.com/c.png',
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    );

    expect(image.fit, BoxFit.contain);
    expect(image.alignment, Alignment.bottomCenter);
  });
}
