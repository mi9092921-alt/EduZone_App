import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/streaming_video_info.dart';

/// Remote data source for Player4 operations.
///
/// Handles Supabase Edge Function calls for fetching direct streaming video info.
class Player4RemoteDataSource {
  final SupabaseClient _client;

  Player4RemoteDataSource([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetches streaming video info from Supabase Edge Function.
  Future<StreamingVideoInfo> getVideoInfo(String videoId) async {
    final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
    try {
      debugPrint('🔍 [Player4DS] Invoking video-info for: $videoUrl');

      final response = await _client.functions.invoke(
        'video-info',
        body: {'url': videoUrl},
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
      );
    } catch (e, st) {
      debugPrint('🔴 [Player4DS] Unexpected exception: ${e.runtimeType}');
      debugPrint('🔴 [Player4DS] StackTrace:\n$st');
      throw ServerException(e.toString());
    }
  }
}
