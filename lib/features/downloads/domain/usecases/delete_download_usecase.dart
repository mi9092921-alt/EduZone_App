import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/download_repository.dart';

/// Use case for deleting a downloaded lesson.
class DeleteDownloadUseCase {
  final DownloadRepository _repository;

  DeleteDownloadUseCase(this._repository);

  Future<Either<Failure, void>> call(String downloadId) {
    return _repository.deleteDownload(downloadId);
  }
}
