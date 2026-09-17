import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/shared/models/course.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../helpers/feature_flag_overrides.dart';

/// Wraps [child] with the localization + theme + provider scaffolding every
/// course widget test needs. Mirrors `course_card_test_helpers.dart` so the
/// split `course_details_screen` / `course_preview_screen` widgets follow
/// the same test-setup convention as the rest of the courses feature.
///
/// Since `CourseRatingSection` joined the About tab, course widgets touch
/// Riverpod providers (feature flags, enrollment, own rating). Those three
/// are surfaced as [flagValues] / [enrolled] / [myRating] parameters —
/// NOT as pass-through overrides — so a test cannot stack a second
/// override for the same provider (duplicate overrides throw in Riverpod).
/// [overrides] is reserved for any other provider a test needs to pin.
Widget buildTestableWidget(
  Widget child, {
  Locale locale = const Locale('en'),
  Map<FeatureFlagKey, bool> flagValues = const {},
  bool enrolled = false,
  int? myRating,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      featureFlagsOverride(flagValues),
      isEnrolledProvider.overrideWith(
        (ref, courseId) => AsyncValue<bool>.data(enrolled),
      ),
      myCourseRatingProvider.overrideWith((ref, courseId) async => myRating),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
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
