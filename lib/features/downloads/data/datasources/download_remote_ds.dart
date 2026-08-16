import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../data/models/video_info.dart';

/// Remote data source for download-related operations.
///
/// Handles Supabase Edge Function calls for validating access, fetching video
/// info, and logging download analytics.
class DownloadRemoteDataSource {
  final SupabaseClient _client;

  DownloadRemoteDataSource(this._client);

  /// Creates/claims a server-authoritative offline entitlement. This is
  /// deliberately separate from ordinary lesson access: preview/online
  /// access never implies offline authorization.
  Future<Map<String, dynamic>> authorizeOfflineDownload({
    required String lessonId,
    required String courseId,
    required String downloadId,
  }) async {
    try {
      final deviceId = DeviceInfoHelper.fingerprint;
      if (deviceId.isEmpty) {
        throw const ServerException('Device binding is unavailable'); // check-ignore
      }
      final data = await _client.rpc(
        'authorize_offline_download',
        params: {
          'p_lesson_id': lessonId,
          'p_course_id': courseId,
          'p_device_id': deviceId,
          'p_download_id': downloadId,
        },
      );
      if (data is! Map<String, dynamic> ||
          data['status'] != 'ACTIVE' ||
          data['entitlement_id'] == null) {
        throw const ServerException('Offline authorization was denied'); // check-ignore
      }
      return data;
    } on PostgrestException catch (e) {
      throw ServerException('Offline authorization was denied: ${e.code}'); // check-ignore
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Offline authorization failed'); // check-ignore
    }
  }

  /// Revalidates an existing entitlement when connectivity is available.
  /// Network failures are surfaced to the caller so the playback gate can
  /// distinguish "server says deny" from "device is currently offline".
  Future<Map<String, dynamic>> revalidateOfflineEntitlement({
    required String entitlementId,
  }) async {
    final deviceId = DeviceInfoHelper.fingerprint;
    if (deviceId.isEmpty) {
      throw const ServerException('Device binding is unavailable'); // check-ignore
    }
    try {
      final data = await _client.rpc(
        'revalidate_offline_entitlement',
        params: {
          'p_entitlement_id': entitlementId,
          'p_device_id': deviceId,
        },
      );
      if (data is! Map<String, dynamic>) {
        throw const ServerException('Invalid offline revalidation response'); // check-ignore
      }
      return data;
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      final transient = code.startsWith('08') ||
          code.startsWith('53') ||
          code == 'PGRST000' ||
          code == 'PGRST001' ||
          code == 'PGRST002' ||
          code == 'PGRST003';
      throw ServerException(
        'Offline entitlement revalidation failed', // check-ignore
        transient ? 'network_error' : 'server_error', // check-ignore: internal error-code classifier, never rendered
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        'Offline entitlement revalidation failed', // check-ignore
        e is SocketException ? 'network_error' : 'server_error', // check-ignore: internal error-code classifier, never rendered
      );
    }
  }

  /// Validates access for a lesson or course.
  Future<CourseAccessResult> validateCourseAccess({
    String? lessonId,
    String? courseId,
  }) async {
    final body = <String, dynamic>{};
    if (lessonId != null) body['lesson_id'] = lessonId;
    if (courseId != null) body['course_id'] = courseId;

    assert(() {
      debugPrint('🔍 validateCourseAccess → request body: $body');
      return true;
    }());

    try {
      final response = await _client.functions.invoke(
        'validate-course-access',
        body: body,
      );

      assert(() {
        debugPrint('🔍 validateCourseAccess → status: ${response.status}');
        return true;
      }());

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ServerException('Invalid validate-course-access response'); // check-ignore
      }

      assert(() {
        debugPrint('🔍 validateCourseAccess → allowed=${data["allowed"]}, reason=${data["reason"]}');
        return true;
      }());

      return CourseAccessResult.fromJson(data);
    } on FunctionException catch (e) {
      assert(() {
        debugPrint('🔍 validateCourseAccess → FunctionException: status=${e.status}');
        return true;
      }());
      throw ServerException(
        'Failed to validate course access: ${e.details ?? e.reasonPhrase ?? e.status}', // check-ignore
      );
    } catch (e) {
      assert(() {
        debugPrint('🔍 validateCourseAccess → Exception: $e');
        return true;
      }());
      throw ServerException(e.toString());
    }
  }

  /// Fetches video info (available formats, sizes) for a YouTube URL.
  Future<VideoInfo> getVideoInfo(String url) async {
    try {
      assert(() {
        debugPrint('🔍 video-info Edge Function → request url: $url');
        return true;
      }());
      final response = await _client.functions.invoke(
        'video-info',
        body: {'url': url},
      );

      assert(() {
        debugPrint('🔍 video-info Edge Function → status: ${response.status}');
        return true;
      }());

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ServerException('Invalid video-info response'); // check-ignore
      }

      return VideoInfo.fromJson(data);
    } on FunctionException catch (e) {
      assert(() {
        debugPrint('🔍 video-info → FunctionException: status=${e.status}');
        return true;
      }());
      throw ServerException(
        'Failed to fetch video info: ${e.details ?? e.reasonPhrase ?? e.status}', // check-ignore
      );
    } catch (e) {
      assert(() {
        debugPrint('🔍 video-info → Exception: $e');
        return true;
      }());
      throw ServerException(e.toString());
    }
  }

  /// Logs a successful download attempt.
  Future<void> logDownloadAttempt({
    required String lessonId,
    required String quality,
    DateTime? accessExpiresAt,
  }) async {
    final body = {
      'lesson_id': lessonId,
      'quality': quality,
      'access_expires_at': accessExpiresAt?.toIso8601String(),
    };

    try {
      final response = await _client.functions.invoke(
        'log-download-attempt',
        body: body,
      );

      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        throw const ServerException('Failed to log download attempt'); // check-ignore
      }
    } on FunctionException catch (e) {
      throw ServerException(
        'Failed to log download attempt: ${e.details ?? e.reasonPhrase ?? e.status}', // check-ignore
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
