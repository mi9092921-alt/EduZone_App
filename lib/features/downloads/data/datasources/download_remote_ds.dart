import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../data/models/video_info.dart';

/// Remote data source for download-related operations.
///
/// Handles Supabase Edge Function calls for validating access, fetching video
/// info, and logging download analytics.
///
/// Section 13 hardening pass: every RPC/Edge Function call in this file
/// previously had zero client-side timeout -- including
/// `authorizeOfflineDownload`/`revalidateOfflineEntitlement`, the P6
/// offline-entitlement gate that decides whether a download or offline
/// playback is allowed at all. A stalled connection during either left
/// the download flow hanging indefinitely with no distinguishable
/// failure state, rather than the "server says deny" vs "device is
/// currently offline" distinction the code already goes out of its way
/// to make for genuine (non-hung) failures. See Section 13 ("Networking
/// Reliability") of the project instructions.
class DownloadRemoteDataSource {
  final SupabaseClient _client;

  DownloadRemoteDataSource(this._client);

  /// Creates/claims a server-authoritative offline entitlement. This is
  /// deliberately separate from ordinary lesson access: preview/online
  /// access never implies offline authorization.
  ///
  /// Routed through `NetworkGuard.write` (bounded timeout, never
  /// auto-retried): this RPC claims/consumes a server-side entitlement
  /// slot, so blindly retrying it on a client-perceived timeout risks the
  /// claim having already succeeded server-side.
  Future<Map<String, dynamic>> authorizeOfflineDownload({
    required String lessonId,
    required String courseId,
    required String downloadId,
  }) async {
    return NetworkGuard.write(() async {
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
        if (e is AppException) rethrow;
        throw const ServerException('Offline authorization failed'); // check-ignore
      }
    });
  }

  /// Revalidates an existing entitlement when connectivity is available.
  /// Network failures are surfaced to the caller so the playback gate can
  /// distinguish "server says deny" from "device is currently offline".
  ///
  /// Routed through `NetworkGuard.write` for the timeout bound. Not
  /// `.read`: this file's own catch blocks below already fully classify
  /// every failure (including a raw `SocketException`/`TimeoutException`)
  /// into a `ServerException` with an internal `network_error` vs
  /// `server_error` code before it would ever reach `NetworkGuard`'s own
  /// retry decision, so `.read`'s retry path would never actually trigger
  /// here -- `.write` states that intent honestly instead of implying a
  /// retry behavior this method doesn't have.
  Future<Map<String, dynamic>> revalidateOfflineEntitlement({
    required String entitlementId,
  }) async {
    return NetworkGuard.write(() async {
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
          e is SocketException || e is TimeoutException
              ? 'network_error' // check-ignore: internal error-code classifier, never rendered
              : 'server_error', // check-ignore: internal error-code classifier, never rendered
        );
      }
    });
  }

  /// Validates access for a lesson or course.
  ///
  /// Routed through `NetworkGuard.read` with `NetworkConfig.heavyTimeout`:
  /// an Edge Function invocation (not a plain table read), matching the
  /// budget already used for the identical class of call in
  /// `ProfileRemoteDataSource.uploadAvatar` and
  /// `Player4RemoteDataSource.getVideoInfo`. Safe to retry on a genuine
  /// transient connectivity failure -- this is a read-only access check
  /// with no server-side side effects; a real `FunctionException` (an
  /// actual allow/deny decision) is classified and rethrown before
  /// `NetworkGuard` ever sees it, so it is never retried.
  Future<CourseAccessResult> validateCourseAccess({
    String? lessonId,
    String? courseId,
  }) async {
    final body = <String, dynamic>{};
    if (lessonId != null) body['lesson_id'] = lessonId;
    if (courseId != null) body['course_id'] = courseId;

    return NetworkGuard.read(
      () async {
        try {
          assert(() {
            debugPrint('🔍 validateCourseAccess → request body: $body');
            return true;
          }());

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
          if (e is AppException) rethrow;
          throw NetworkExceptionMapper.map(e);
        }
      },
      timeout: NetworkConfig.heavyTimeout,
    );
  }

  /// Fetches video info (available formats, sizes) for a YouTube URL.
  ///
  /// Previously had no client-side timeout -- unlike the near-identical
  /// `video-info` invocation in `Player4RemoteDataSource.getVideoInfo`,
  /// which already used `NetworkGuard.read(timeout: heavyTimeout)`. This
  /// mirrors that fix for consistency: an Edge Function doing external
  /// work can legitimately take longer than a plain read, and a read-only
  /// call is safe to retry on genuine transient connectivity failure.
  Future<VideoInfo> getVideoInfo(String url) async {
    return NetworkGuard.read(
      () async {
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
          if (e is AppException) rethrow;
          throw NetworkExceptionMapper.map(e);
        }
      },
      timeout: NetworkConfig.heavyTimeout,
    );
  }

  /// Logs a successful download attempt.
  ///
  /// Routed through `NetworkGuard.write` (bounded, never auto-retried --
  /// it is a mutation/log write, not a read) with `NetworkConfig
  /// .heavyTimeout` since this is an Edge Function invocation rather than
  /// a plain table write.
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

    return NetworkGuard.write(
      () async {
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
          if (e is AppException) rethrow;
          throw NetworkExceptionMapper.map(e);
        }
      },
      timeout: NetworkConfig.heavyTimeout,
    );
  }
}
