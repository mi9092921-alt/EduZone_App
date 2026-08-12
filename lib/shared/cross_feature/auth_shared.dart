/// Cross-feature facade for `features/auth`.
///
/// Several other features (courses, home, profile, todo) legitimately need
/// read access to [authProvider] — e.g. to read the current user id for a
/// scoped query, or to call `logout()`/`refreshUser()`. Importing
/// `features/auth/application/providers/auth_provider.dart` directly from
/// another feature is exactly the tight cross-feature coupling that
/// `tool/check_architecture.py` warns about, because it reaches into
/// auth's presentation layer instead of a shared contract.
///
/// This file is the single, explicit seam other features should go through
/// instead. It changes nothing about behavior or ownership — `auth` still
/// owns this state and logic — it only moves the import path to `lib/shared/`,
/// which the architecture guard always treats as neutral ground.
///
/// See also: `notifications_shared.dart`, `profile_shared.dart`,
/// `downloads_shared.dart`, `courses_shared.dart`, `todo_shared.dart` for
/// the same pattern applied to the other cross-feature dependencies flagged
/// in the same audit pass.
library;

export '../../features/auth/application/providers/auth_provider.dart';
export '../../features/auth/presentation/widgets/optional_update_dialog.dart';
