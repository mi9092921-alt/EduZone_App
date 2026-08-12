import 'package:app/design_system/design_system.dart';
import 'package:app/features/video_player/presentation/screens/video_player/video_player_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders without throwing, standalone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VideoPlayerSkeleton()),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('renders without throwing when wrapped in AppSkeleton '
      '(as used by video_player_screen.dart)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppSkeleton(child: VideoPlayerSkeleton()),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders exactly 5 placeholder lesson tiles', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: VideoPlayerSkeleton()),
    );

    expect(find.byType(ListTile), findsNWidgets(5));
  });
}
