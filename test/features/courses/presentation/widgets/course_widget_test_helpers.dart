import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:flutter/material.dart';

/// Wraps [child] with the localization + theme scaffolding every course
/// widget test needs. Mirrors `course_card_test_helpers.dart` so the split
/// `course_details_screen` / `course_preview_screen` widgets follow the
/// same test-setup convention as the rest of the courses feature.
Widget buildTestableWidget(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// A fully-populated course fixture (paid, with learning objectives,
/// prerequisites and an instructor but no avatar, so tests never hit the
/// network via `AppNetworkImage`).
const tFullCourse = Course(
  id: 'course-1',
  tenantId: 'tenant-1',
  title: 'Flutter for Beginners',
  description: 'Learn Flutter from scratch, step by step.',
  status: 'published',
  price: 49.99,
  isFree: false,
  learningObjectives: ['Build layouts', 'Manage state'],
  prerequisites: ['Basic Dart knowledge'],
  instructorName: 'Jane Doe',
);

/// A minimal free course with no learning objectives/prerequisites, used to
/// verify those optional sections are hidden rather than rendered empty.
const tMinimalFreeCourse = Course(
  id: 'course-2',
  tenantId: 'tenant-1',
  title: 'Intro Course',
  status: 'published',
);
