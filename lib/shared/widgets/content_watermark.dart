import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Derives the privacy-safe watermark fragment for [userId].
///
/// Only the last 4 characters of the (opaque, server-issued) user id are
/// shown — enough to trace a leaked recording back to an account, without
/// exposing a name, email, phone number, or the full identifier. Returns
/// '' when there is no usable id so callers render nothing instead of
/// guessing (see [ContentWatermark]).
String watermarkFragmentForUserId(String? userId) {
  if (userId == null || userId.length < 4) return '';
  return userId.substring(userId.length - 4).toUpperCase();
}

/// Non-interactive content watermark rendered over video playback.
///
/// Security posture (Phase 11):
/// * This is a deterrence/traceability aid, NOT a security boundary —
///   screen capture itself is blocked separately (`FLAG_SECURE` on Android,
///   `screen_protector` elsewhere). It must never be treated as proof that
///   content cannot be exfiltrated.
/// * The root is [IgnorePointer], so the overlay can never swallow, block,
///   or delay pointer events meant for player controls (play/pause, seek,
///   volume, speed, quality, fullscreen, subtitles). Verified by
///   `content_watermark_test.dart`.
/// * Callers place it over the video area only (top corner, clear of the
///   top control bar and the bottom seek/progress UI) so it never visually
///   covers controls, subtitles, or progress indicators.
/// * Content is restricted to [watermarkText] — a pre-computed opaque id
///   fragment (see [watermarkFragmentForUserId]). Never pass a name, email,
///   phone number, or full token here.
class ContentWatermark extends StatelessWidget {
  final String watermarkText;

  const ContentWatermark({super.key, required this.watermarkText});

  @override
  Widget build(BuildContext context) {
    if (watermarkText.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Opacity(
        opacity: 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.hairline,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: AppRadius.xsBorder,
          ),
          child: Text(
            watermarkText,
            style: AppTextStyles.labelTiny.copyWith(color: AppColors.neutral0),
          ),
        ),
      ),
    );
  }
}
