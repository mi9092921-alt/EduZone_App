import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/download_repository.dart';

/// Use case for pausing an active download.
class PauseDownloadUseCase {
  final DownloadRepository _repository;

  PauseDownloadUseCase(this._repository);

  Future<Either<Failure, void>> call(String downloadId) {
    return _repository.pauseDownload(downloadId);
  }
}
