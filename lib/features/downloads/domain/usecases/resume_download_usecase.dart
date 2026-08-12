import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/download_repository.dart';

/// Use case for resuming a paused download.
class ResumeDownloadUseCase {
  final DownloadRepository _repository;

  ResumeDownloadUseCase(this._repository);

  Future<Either<Failure, void>> call(String downloadId) {
    return _repository.resumeDownload(downloadId);
  }
}
