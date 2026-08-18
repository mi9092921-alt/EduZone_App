import '../../../../core/error/exceptions.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_ds.dart';

/// Implementation of [ProfileRepository] using Supabase.
///
/// Wraps all remote calls in try/catch for consistent error handling.
/// Preserves the typed exception the data source already produced
/// (`NoInternetException`/`RequestTimeoutException`/`ServerException` via
/// `NetworkGuard`/`NetworkExceptionMapper`) instead of re-wrapping
/// everything into an opaque `ServerException` string, which previously
/// discarded that classification one layer above where it was
/// established.
class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  ProfileRepositoryImpl({ProfileRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? ProfileRemoteDataSource();

  @override
  Future<StudentProfile> getProfile() async {
    try {
      return await _remoteDataSource.getProfile();
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(
        'Failed to load profile: ${e.toString()}', // check-ignore
      );
    }
  }

  @override
  Future<StudentProfile> updateProfile({
    String? firstName,
    String? lastName,
  }) async {
    try {
      return await _remoteDataSource.updateProfile(
        firstName: firstName,
        lastName: lastName,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(
        'Failed to update profile: ${e.toString()}', // check-ignore
      );
    }
  }

  @override
  Future<String> uploadAvatar(String filePath) async {
    try {
      return await _remoteDataSource.uploadAvatar(filePath);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(
        'Failed to upload avatar: ${e.toString()}', // check-ignore
      );
    }
  }
}
