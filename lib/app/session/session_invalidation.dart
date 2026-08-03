import 'package:app/features/courses/presentation/providers/courses_provider.dart';
import 'package:app/features/home/presentation/providers/home_provider.dart';
import 'package:app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:app/features/profile/presentation/providers/profile_provider.dart';
import 'package:app/features/todo/presentation/providers/todo_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Composition-root aggregator for "invalidate everything user-scoped on
/// logout" (ARCH-001).
///
/// Previously `auth_provider.dart` imported all five of these feature
/// provider files directly, which the architecture guard
/// (tool/check_architecture.py) flags as cross-feature coupling -- the
/// `auth` feature reaching into `courses`/`home`/`notifications`/`profile`/
/// `todo` internals directly.
///
/// Moving the aggregation here instead is the composition-root pattern:
/// files under lib/app/** are the one place allowed to know about every
/// feature at once (see check_architecture.py's EXEMPT_PATH_FRAGMENTS).
/// `auth_provider.dart` now depends only on this single file instead of on
/// five separate feature internals.
void invalidateAllUserScopedProviders(Ref ref) {
  invalidateProfileProviders(ref);
  invalidateCoursesProviders(ref);
  invalidateTodoProviders(ref);
  invalidateHomeProviders(ref);
  invalidateNotificationsProviders(ref);
}
