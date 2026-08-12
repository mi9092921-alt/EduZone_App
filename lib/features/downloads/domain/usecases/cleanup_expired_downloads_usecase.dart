import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/download_repository.dart';

/// Use case for cleaning up expired downloads.
class CleanupExpiredDownloadsUseCase {
  final DownloadRepository _repository;

  CleanupExpiredDownloadsUseCase(this._repository);

  Future<Either<Failure, int>> call() {
    return _repository.cleanupExpiredDownloads();
  }
}
