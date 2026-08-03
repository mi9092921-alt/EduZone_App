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
  final String? error;
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
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ProfileActionsState(
      isUpdating: isUpdating ?? this.isUpdating,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

@riverpod
class ProfileActions extends _$ProfileActions {
  @override
  ProfileActionsState build() => const ProfileActionsState();

  /// Update first/last name.
  Future<bool> updateName({
    String? firstName,
    String? lastName,
  }) async {
    state = state.copyWith(isUpdating: true, clearError: true, clearSuccess: true);

    try {
      await ref.read(updateProfileUseCaseProvider).call(
        firstName: firstName,
        lastName: lastName,
      );

      // Invalidate profile provider to refetch
      ref.invalidate(profileProvider);

      // Refresh global auth user to update headers/session-bound UI
      await ref.read(authProvider.notifier).refreshUser();

      state = state.copyWith(
        isUpdating: false,
        successMessage: 'profile_updated',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Upload avatar from local file path.
  Future<bool> uploadAvatar(String filePath) async {
    state = state.copyWith(isUploadingAvatar: true, clearError: true, clearSuccess: true);

    try {
      await ref.read(updateProfileUseCaseProvider).uploadAvatar(filePath);

      // Invalidate to refetch and show new avatar
      ref.invalidate(profileProvider);

      // Refresh global auth user
      await ref.read(authProvider.notifier).refreshUser();

      state = state.copyWith(
        isUploadingAvatar: false,
        successMessage: 'avatar_updated',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isUploadingAvatar: false,
        error: e.toString(),
      );
      return false;
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
  ref.invalidate(profileRepositoryProvider);
}