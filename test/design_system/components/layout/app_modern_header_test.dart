import 'dart:ui';

import 'package:app/design_system/components/layout/app_modern_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the title text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppModernHeader(title: 'My Courses'),
        ),
      ),
    );

    expect(find.text('My Courses'), findsOneWidget);
  });

  testWidgets('renders an optional leading widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppModernHeader(
            title: 'Title',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('renders trailing action widgets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppModernHeader(
            title: 'Title',
            actions: [
              IconButton(icon: const Icon(Icons.search), onPressed: () {}),
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('preferredSize matches the standard toolbar height',
      (tester) async {
    const header = AppModernHeader(title: 'Title');
    expect(header.preferredSize, const Size.fromHeight(kToolbarHeight));
  });

  testWidgets('renders without a blur filter when showBlur is false',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppModernHeader(title: 'Title', showBlur: false),
        ),
      ),
    );

    final backdropFilter = tester.widget<BackdropFilter>(
      find.byType(BackdropFilter),
    );
    // sigmaX/Y are driven to 0 when showBlur is false -- the widget stays
    // in the tree either way, but should have no visible blur.
    expect(
      backdropFilter.filter,
      ImageFilter.blur(),
    );
  });
}
