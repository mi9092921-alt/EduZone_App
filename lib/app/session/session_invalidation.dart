import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/home/application/providers/home_provider.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/profile/application/providers/profile_provider.dart';
import 'package:app/features/todo/application/providers/todo_provider.dart';
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
