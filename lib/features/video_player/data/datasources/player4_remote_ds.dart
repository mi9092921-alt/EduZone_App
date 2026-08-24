import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/streaming_video_info.dart';

/// Remote data source for Player4 operations.
///
/// Handles Supabase Edge Function calls for fetching direct streaming video info.
class Player4RemoteDataSource {
  final SupabaseClient? _explicitClient;
  SupabaseClient get _client => _explicitClient ?? SupabaseService.client;

  Player4RemoteDataSource([SupabaseClient? client])
      : _explicitClient = client;

  /// Fetches streaming video info from Supabase Edge Function.
  ///
  /// Previously had no client-side timeout at all -- an Edge Function
  /// call is exactly the kind of request that can legitimately hang
  /// (it does its own outbound fetch/scrape before responding), so this
  /// used [NetworkConfig.heavyTimeout] rather than the default read
  /// budget. It's still a read (no server-side side effects), so
  /// bounded retry via `NetworkGuard.read` applies for genuine
  /// connectivity/timeout failures -- not for a real `FunctionException`
  /// (a definite 4xx/5xx from the function itself, which retrying
  /// blindly would not fix).
  ///
  /// [lessonId], when supplied, is forwarded as `lesson_id` so the
  /// `video-info` Edge Function re-runs its own `get_lesson_content`
  /// authorization check and resolves the URL from the lesson record
  /// itself rather than trusting the client-supplied `url` -- closing the
  /// "authenticated but not entitled to this specific lesson" gap for the
  /// streaming player (see supabase/functions/video-info/index.ts).
  ///
  /// Verified 2026-08-24: this parameter is optional at the API level only
  /// as a defensive contract. The sole current caller, `Player4Wrapper`,
  /// declares `lessonId` as a required (non-nullable) field and always
  /// sets `player4PendingLessonIdProvider` from it before this method runs
  /// -- so in the current codebase every call is already lesson-scoped.
  /// If a future caller is added without a lesson context, it will silently
  /// fall back to the authenticated+rate-limited (not lesson-scoped) gate;
  /// treat any new caller that omits [lessonId] as a finding to review, not
  /// as expected behavior.
  Future<StreamingVideoInfo> getVideoInfo(
    String videoId, {
    String? lessonId,
  }) async {
    final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
    return NetworkGuard.read(
      () async {
        try {
          debugPrint('🔍 [Player4DS] Invoking video-info for: $videoUrl');

          final response = await _client.functions.invoke(
            'video-info',
            body: {
              'url': videoUrl,
              if (lessonId != null && lessonId.trim().isNotEmpty)
                'lesson_id': lessonId,
            },
          );

          // If we reach here, status is guaranteed 200-299.
          // functions_client 2.5.0 throws FunctionException on any non-2xx.
          debugPrint('🔍 [Player4DS] video-info success: status=${response.status}');

          final data = response.data;
          if (data is! Map<String, dynamic>) {
            debugPrint('🔴 [Player4DS] Unexpected response type: ${data.runtimeType}');
            throw const ServerException('Invalid video-info response format'); // check-ignore
          }

          return StreamingVideoInfo.fromJson(data);
        } on FunctionException catch (e) {
          // Thrown automatically by functions_client for any non-2xx status code.
          debugPrint('🔴 [Player4DS] FunctionException: status=${e.status}');
          debugPrint('🔴 [Player4DS] details: ${e.details}');
          debugPrint('🔴 [Player4DS] reasonPhrase: ${e.reasonPhrase}');
          throw ServerException(
            'Edge Function error ${e.status}: ${e.details ?? e.reasonPhrase ?? "unknown"}', // check-ignore
            e.status.toString(),
          );
        } catch (e, st) {
          if (e is AppException) rethrow;
          debugPrint('🔴 [Player4DS] Unexpected exception: ${e.runtimeType}');
          debugPrint('🔴 [Player4DS] StackTrace:\n$st');
          throw NetworkExceptionMapper.map(e);
        }
      },
      timeout: NetworkConfig.heavyTimeout,
    );
  }
}
