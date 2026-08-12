import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/download_repository.dart';

/// Use case for canceling a download.
class CancelDownloadUseCase {
  final DownloadRepository _repository;

  CancelDownloadUseCase(this._repository);

  Future<Either<Failure, void>> call(String downloadId) {
    return _repository.cancelDownload(downloadId);
  }
}
