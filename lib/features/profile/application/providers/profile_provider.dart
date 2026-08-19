import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/cross_feature/auth_shared.dart';
import '../../data/repositories/profile_repo_impl.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/update_profile.dart';

part 'profile_provider.g.dart';

// ─── Repository & Use Case Providers ─────────────────────────────────────────

@riverpod
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepositoryImpl();
}

@riverpod
GetProfile getProfileUseCase(Ref ref) {
  return GetProfile(ref.watch(profileRepositoryProvider));
}

@riverpod
UpdateProfile updateProfileUseCase(Ref ref) {
  return UpdateProfile(ref.watch(profileRepositoryProvider));
}

// ─── Profile Data Provider ───────────────────────────────────────────────────

@riverpod
Future<StudentProfile> profile(Ref ref) async {
  return ref.read(getProfileUseCaseProvider).call();
}

// ─── Profile Actions Notifier ────────────────────────────────────────────────

class ProfileActionsState {
  final bool isUpdating;
  final bool isUploadingAvatar;

  /// The error from the last failed update/upload, or `null`. Kept as the
  /// typed exception (not a pre-formatted `String`) so the UI can
  /// classify it via `ErrorHandler.getMessage()` at display time --
  /// notifiers have no `BuildContext`/localization access, so
  /// classification can't happen here. Previously this stored
  /// `e.toString()` directly: an internal, unlocalized diagnostic string.
  /// See Section 13/14 hardening pass.
  final Object? error;
  final String? successMessage;

  const ProfileActionsState({
    this.isUpdating = false,
    this.isUploadingAvatar = false,
    this.error,
    this.successMessage,
  });

  ProfileActionsState copyWith({
    bool? isUpdating,
    bool? isUploadingAvatar,
    Object? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ProfileActionsState(
      isUpdating: isUpdating ?? this.isUpdating,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

@riverpod
class ProfileActions extends _$ProfileActions {
  @override
  ProfileActionsState build() => const ProfileActionsState();

  /// Update first/last name.
  Future<bool> updateName({String? firstName, String? lastName}) async {
    // FIX (FLUTTER-A/9): ProfileActions is autoDispose (default for
    // @riverpod class) and the UI only ever does `ref.read(...notifier)`
    // (never `watch`), so nothing keeps this notifier alive across the
    // first `await` below. Riverpod can dispose it mid-flight, and any
    // `ref`/`state` access afterwards — including inside `catch` — then
    // throws UnmountedRefException uncaught. Must be called before any
    // `await` (see player4_provider.dart for the same established
    // pattern in this codebase).
    final keepAliveLink = ref.keepAlive();
    state = state.copyWith(
      isUpdating: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await ref
          .read(updateProfileUseCaseProvider)
          .call(firstName: firstName, lastName: lastName);
      // The backend write already succeeded at this point regardless of
      // what happens below, so treat disposal here as success, not error.
      if (!ref.mounted) return true;

      // Invalidate profile provider to refetch
      ref.invalidate(profileProvider);

      // Refresh global auth user to update headers/session-bound UI
      await ref.read(authProvider.notifier).refreshUser();
      if (!ref.mounted) return true;

      state = state.copyWith(
        isUpdating: false,
        successMessage: 'profile_updated',
      );
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isUpdating: false, error: e);
      }
      return false;
    } finally {
      // Release the keep-alive once this operation settles so the
      // notifier can still be garbage-collected normally afterwards.
      keepAliveLink.close();
    }
  }

  /// Upload avatar from local file path.
  Future<bool> uploadAvatar(String filePath) async {
    // See updateName() above for why this must be acquired before the
    // first `await` (FLUTTER-A/9).
    final keepAliveLink = ref.keepAlive();
    state = state.copyWith(
      isUploadingAvatar: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await ref.read(updateProfileUseCaseProvider).uploadAvatar(filePath);
      if (!ref.mounted) return true;

      // Invalidate to refetch and show new avatar
      ref.invalidate(profileProvider);

      // Refresh global auth user
      await ref.read(authProvider.notifier).refreshUser();
      if (!ref.mounted) return true;

      state = state.copyWith(
        isUploadingAvatar: false,
        successMessage: 'avatar_updated',
      );
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isUploadingAvatar: false, error: e);
      }
      return false;
    } finally {
      keepAliveLink.close();
    }
  }
}

// ─── Session cleanup ─────────────────────────────────────────────────────────

/// Invalidates every user-scoped provider owned by the `profile` feature.
///
/// Called by [Auth.logout] on sign-out to guarantee zero data leakage
/// between sessions. **When you add a new user-scoped provider to this
/// file, add it here too** — this list is intentionally kept next to the
/// providers it covers so it's easy to remember, instead of living in a
/// distant, unrelated `auth` file.
void invalidateProfileProviders(Ref ref) {
  ref.invalidate(profileProvider);
  ref.invalidate(profileActionsProvider);
  ref.invalidate(profileRepositoryProvider);
}
