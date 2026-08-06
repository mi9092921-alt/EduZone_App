/// Barrel export for the course card family of widgets.
///
/// This file used to contain all of the implementation directly (969 lines).
/// It has been split into `course_card/` by responsibility for
/// maintainability — see that folder for the actual source. This barrel
/// keeps the original import path (`package:app/shared/components/course_card.dart`)
/// working unchanged for all existing consumers and tests.
library;

export 'course_card/course_card_badges.dart' show CourseCardOverlayBadge;
export 'course_card/course_card_base.dart' show CourseCardBase;
export 'course_card/course_card_data.dart'
    show CourseCardData, DiscoverCourseVM, MyCourseVM, RecentCourseVM;
export 'course_card/course_card_progress_bar.dart' show CourseCardProgressBar;
export 'course_card/course_card_shimmers.dart'
    show
        DiscoverCourseCardShimmer,
        MyCourseCardShimmer,
        RecentCourseCardShimmer;
export 'course_card/discover_course_card.dart' show DiscoverCourseCard;
export 'course_card/my_course_card.dart' show MyCourseCard;
export 'course_card/recent_course_card.dart' show RecentCourseCard;
