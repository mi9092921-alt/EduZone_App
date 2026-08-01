import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/components/course_card.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';

/// A wrapper for CourseCard specifically for "My Courses" preview.
class MyCoursesPreview extends StatelessWidget {
  final CourseEnrollment? enrollment;
  final bool isLoading;

  const MyCoursesPreview({super.key, this.enrollment, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    if (isLoading || enrollment == null) {
      return const MyCourseCardShimmer(isHorizontal: true);
    }

    final course = enrollment!.course;
    if (course == null) return const SizedBox.shrink();

    final totalLessons =
        course.totalLessons ??
        course.computedTotalLessons;

    final vm = MyCourseVM(
      id: course.id,
      title: course.title,
      thumbnailUrl: course.thumbnailUrl ?? '',
      level: course.level,
      totalLessons: enrollment!.totalLessons > 0 
          ? enrollment!.totalLessons 
          : totalLessons,
      progress: enrollment!.progressPct / 100.0,
    );

    return MyCourseCard(
      data: vm,
      isHorizontal: true,
      onTap: () {
        context.go('${AppRoutes.courses}/${course.id}');
      },
    );
  }
}
