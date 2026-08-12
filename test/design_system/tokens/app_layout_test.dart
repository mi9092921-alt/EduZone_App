import 'package:app/design_system/tokens/app_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLayout', () {
    test('aspect ratios are positive and video matches card (both 16:9)', () {
      expect(AppLayout.cardAspectRatio, closeTo(16 / 9, 0.0001));
      expect(AppLayout.videoAspectRatio, closeTo(16 / 9, 0.0001));
      expect(AppLayout.cardAspectRatio, AppLayout.videoAspectRatio);
      expect(AppLayout.thumbnailAspectRatio, closeTo(4 / 3, 0.0001));
      expect(AppLayout.squareAspectRatio, 1.0);
    });

    test('grid column counts increase with breakpoint width', () {
      expect(
        AppLayout.gridColumnsMobile,
        lessThan(AppLayout.gridColumnsTablet),
      );
      expect(
        AppLayout.gridColumnsTablet,
        lessThan(AppLayout.gridColumnsDesktop),
      );
    });

    test('sidebar and modal widths stay within the max content width', () {
      expect(
        AppLayout.sidebarWidth,
        lessThan(AppLayout.maxContentWidth),
      );
      expect(
        AppLayout.modalMaxWidth,
        lessThan(AppLayout.maxContentWidth),
      );
    });

    test('dprAwareScale is at least 1x (never downsamples)', () {
      expect(AppLayout.dprAwareScale, greaterThanOrEqualTo(1.0));
    });
  });
}
