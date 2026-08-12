import '../../../design_system/design_system.dart';

/// Base view-model contract shared by every course card variant.
///
/// Concrete cards ([DiscoverCourseVM], [MyCourseVM], [RecentCourseVM]) each
/// extend this with the fields specific to the screen that renders them.
abstract class CourseCardData {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String? level;
  final String? instructorName;

  const CourseCardData({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    this.level,
    this.instructorName,
  });
}

/// View-model for [DiscoverCourseCard] (Discover, Search, Saved Courses).
class DiscoverCourseVM extends CourseCardData {
  final int? totalLessons;
  final String? category;
  final double? rating;
  final int? ratingCount;
  final int? studentsCount;
  final int? durationMinutes;
  final double? price;
  final bool isFree;
  final bool isNew;

  const DiscoverCourseVM({
    required super.id,
    required super.title,
    required super.thumbnailUrl,
    super.level,
    super.instructorName,
    this.totalLessons,
    this.category,
    this.rating,
    this.ratingCount,
    this.studentsCount,
    this.durationMinutes,
    this.price,
    this.isFree = true,
    this.isNew = false,
  });

  /// Factory for skeleton dummy data
  factory DiscoverCourseVM.skeleton() => const DiscoverCourseVM(
    id: 'skeleton',
    title: AppSkeletonData.dummyTitle,
    thumbnailUrl: '',
    category: AppSkeletonData.dummyCategory,
    rating: 0.0,
    level: 'BEGINNER',
    instructorName: 'Instructor Name',
  );
}

/// View-model for [MyCourseCard] (My Courses list).
class MyCourseVM extends CourseCardData {
  final int totalLessons;
  final double progress;

  const MyCourseVM({
    required super.id,
    required super.title,
    required super.thumbnailUrl,
    super.level,
    required this.totalLessons,
    required this.progress,
  });

  /// Factory for skeleton dummy data
  factory MyCourseVM.skeleton() => const MyCourseVM(
    id: 'skeleton',
    title: AppSkeletonData.dummyTitle,
    thumbnailUrl: '',
    totalLessons: 10,
    progress: 0.5,
    level: 'BEGINNER',
  );
}

/// View-model for [RecentCourseCard] (recently viewed courses).
class RecentCourseVM extends CourseCardData {
  final int totalLessons;
  final double progress;
  final String? currentLessonTitle;

  const RecentCourseVM({
    required super.id,
    required super.title,
    required super.thumbnailUrl,
    super.level,
    required this.totalLessons,
    required this.progress,
    this.currentLessonTitle,
  });

  /// Factory for skeleton dummy data
  factory RecentCourseVM.skeleton() => const RecentCourseVM(
    id: 'skeleton',
    title: AppSkeletonData.dummyTitle,
    thumbnailUrl: '',
    totalLessons: 10,
    progress: 0.0,
    level: 'BEGINNER',
  );
}
