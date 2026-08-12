import 'package:app/design_system/design_system.dart';
import 'package:app/features/courses/presentation/widgets/course_bullet_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'course_widget_test_helpers.dart';

void main() {
  testWidgets('renders the given text with a check-circle icon', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        Builder(
          builder: (context) => CourseBulletPoint(
            ds: AppColors.of(context),
            text: 'Build production-ready apps',
          ),
        ),
      ),
    );

    expect(find.text('Build production-ready apps'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('renders one bullet per item when used in a list', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        Builder(
          builder: (context) => Column(
            children: ['Point A', 'Point B', 'Point C']
                .map((t) => CourseBulletPoint(ds: AppColors.of(context), text: t))
                .toList(),
          ),
        ),
      ),
    );

    expect(find.byType(CourseBulletPoint), findsNWidgets(3));
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
  });
}
