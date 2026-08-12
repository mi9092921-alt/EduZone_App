import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:flutter/material.dart';

/// Maps a [DownloadStatus] to the icon/color/label used across
/// `DownloadTile` and its sub-widgets.
///
/// Extracted from `download_tile.dart`'s private `_getStatusIcon`,
/// `_getStatusColor`, and `_getStatusText` methods so the mapping is
/// defined once and independently unit-testable — `icon()` needs no
/// [BuildContext] at all, and `color()`/`text()` are pure functions of
/// their explicit parameters.
abstract final class DownloadStatusPresentation {
  static IconData icon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Icons.schedule;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.paused:
        return Icons.pause_circle;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
    }
  }

  static Color color(DownloadStatus status, DesignSystemColors ds) {
    switch (status) {
      case DownloadStatus.pending:
        return ds.textSecondary;
      case DownloadStatus.downloading:
        return ds.primary;
      case DownloadStatus.paused:
        return AppColors.warning;
      case DownloadStatus.completed:
        return ds.success;
      case DownloadStatus.failed:
        return ds.error;
    }
  }

  static String text(DownloadStatus status, AppLocalizations l10n) {
    switch (status) {
      case DownloadStatus.pending:
        return l10n.downloadStatusPending;
      case DownloadStatus.downloading:
        return l10n.downloadStatusDownloading;
      case DownloadStatus.paused:
        return l10n.downloadStatusPaused;
      case DownloadStatus.completed:
        return l10n.downloadStatusCompleted;
      case DownloadStatus.failed:
        return l10n.downloadStatusFailed;
    }
  }
}

/// Formats how long until [expiresAt] in the same tiers `DownloadTile`
/// always used (expired / never / N days / N hours / soon).
///
/// Extracted from `download_tile.dart`'s private
/// `extension on DownloadTile { _getExpirationText }`. [now] is injectable
/// (defaults to [DateTime.now]) specifically so every tier can be unit
/// tested deterministically instead of depending on wall-clock time.
String formatDownloadExpiration(
  DateTime expiresAt,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final difference = expiresAt.difference(now ?? DateTime.now());

  if (difference.isNegative) {
    return l10n.downloadExpired;
  } else if (difference.inDays > 30) {
    return l10n.downloadNeverExpires;
  } else if (difference.inDays > 0) {
    return l10n.downloadExpiresInDays(difference.inDays);
  } else if (difference.inHours > 0) {
    return l10n.downloadExpiresInHours(difference.inHours);
  } else {
    return l10n.downloadExpiresSoon;
  }
}
