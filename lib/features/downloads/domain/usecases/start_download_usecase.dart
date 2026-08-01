import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/download_enums.dart';
import '../entities/downloaded_lesson.dart';
import '../repositories/download_repository.dart';

/// Use case for starting a new download.
class StartDownloadUseCase {
  final DownloadRepository _repository;

  StartDownloadUseCase(this._repository);

  Future<Either<Failure, DownloadedLesson>> call({
    required String lessonId,
    required String courseId,
    required String courseTitle,
    required String title,
    required String videoUrl,
    required VideoQuality quality,
  }) {
    return _repository.startDownload(
      lessonId: lessonId,
      courseId: courseId,
      courseTitle: courseTitle,
      title: title,
      videoUrl: videoUrl,
      quality: quality,
    );
  }
}
