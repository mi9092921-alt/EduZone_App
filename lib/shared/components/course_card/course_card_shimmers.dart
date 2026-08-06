import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import 'course_card_data.dart';
import 'discover_course_card.dart';
import 'my_course_card.dart';
import 'recent_course_card.dart';

/// Loading placeholder for [DiscoverCourseCard].
class DiscoverCourseCardShimmer extends StatelessWidget {
  final bool isHorizontal;
  const DiscoverCourseCardShimmer({super.key, this.isHorizontal = false});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: DiscoverCourseCard(
        data: DiscoverCourseVM.skeleton(),
        isHorizontal: isHorizontal,
      ),
    );
  }
}

/// Loading placeholder for [MyCourseCard].
class MyCourseCardShimmer extends StatelessWidget {
  final bool isHorizontal;
  const MyCourseCardShimmer({super.key, this.isHorizontal = false});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: MyCourseCard(
        data: MyCourseVM.skeleton(),
        isHorizontal: isHorizontal,
      ),
    );
  }
}

/// Loading placeholder for [RecentCourseCard].
class RecentCourseCardShimmer extends StatelessWidget {
  const RecentCourseCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: RecentCourseCard(data: RecentCourseVM.skeleton()),
    );
  }
}
