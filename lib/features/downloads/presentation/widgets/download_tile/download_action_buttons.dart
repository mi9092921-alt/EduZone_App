import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/shared/models/download_enums.dart';
import 'package:app/shared/utils/app_snackbar.dart';
import 'package:app/shared/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/confirm_dialog.dart';
import '../../../application/providers/downloads_provider.dart';

/// Runs a [DownloadsNotifier] action and surfaces a safe, user-facing
/// error message (or any other error) as an error SnackBar instead of
/// letting it become an unhandled Future rejection.
///
/// Extracted from `download_tile.dart`'s private `_performAction` method
/// — mirrors the pattern already used for
/// [DownloadsNotifier.startDownload] in sections_accordion.dart, now
/// shared by [DownloadActionButtons] and [showDownloadDeleteDialog].
Future<void> performDownloadAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message = ErrorHandler.getMessage(context, e);
    AppSnackbar.showError(
      context: context,
      message: l10n.downloadActionFailed(message),
    );
  }
}

/// Shows the "delete this download?" confirmation dialog and, if
/// confirmed, deletes it via [performDownloadAction].
///
/// Extracted from `download_tile.dart`'s private `_showDeleteDialog`
/// method.
void showDownloadDeleteDialog(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  String downloadId,
) {
  showDialog(
    context: context,
    // Named dialogContext (not `context`) deliberately: it must NOT shadow
    // the outer screen `context`, because that outer context is what
    // performDownloadAction needs to still be mounted after the dialog is
    // popped in order to show the error SnackBar.
    builder: (dialogContext) => ConfirmDialog(
      title: l10n.downloadsDeleteTitle,
      description: l10n.downloadsDeleteMsg,
      confirmLabel: l10n.downloadsDeleteBtn,
      cancelLabel: l10n.downloadsCancelBtn,
      isDangerous: true,
      onConfirm: () {
        Navigator.pop(dialogContext);
        performDownloadAction(
          context,
          () => ref.read(downloadsProvider.notifier).deleteDownload(
                downloadId,
              ),
        );
      },
    ),
  );
}

/// The status-dependent row of action icon buttons (pause/resume/cancel/
/// delete/retry) shown at the end of a [DownloadTile] row.
///
/// Extracted from `download_tile.dart`'s private `_buildActionButtons`
/// method and promoted to its own [ConsumerWidget].
class DownloadActionButtons extends ConsumerWidget {
  final String downloadId;
  final DownloadStatus status;

  const DownloadActionButtons({
    super.key,
    required this.downloadId,
    required this.status,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    switch (status) {
      case DownloadStatus.downloading:
        return AppIconButton(
          icon: Icons.pause,
          semanticLabel: l10n.downloadPause,
          onPressed: () => performDownloadAction(
            context,
            () => ref.read(downloadsProvider.notifier).pauseDownload(
                  downloadId,
                ),
          ),
        );
      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: Icons.play_arrow,
              semanticLabel: l10n.downloadResume,
              onPressed: () => performDownloadAction(
                context,
                () => ref.read(downloadsProvider.notifier).resumeDownload(
                      downloadId,
                    ),
              ),
            ),
            AppIconButton(
              icon: Icons.cancel,
              semanticLabel: l10n.downloadCancel,
              onPressed: () => performDownloadAction(
                context,
                () => ref.read(downloadsProvider.notifier).cancelDownload(
                      downloadId,
                    ),
              ),
            ),
          ],
        );
      case DownloadStatus.completed:
        return AppIconButton(
          icon: Icons.delete_outline,
          semanticLabel: l10n.downloadsDeleteBtn,
          onPressed: () =>
              showDownloadDeleteDialog(context, ref, l10n, downloadId),
        );
      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: Icons.refresh,
              semanticLabel: l10n.downloadRetry,
              onPressed: () => performDownloadAction(
                context,
                () => ref.read(downloadsProvider.notifier).resumeDownload(
                      downloadId,
                    ),
              ),
            ),
            AppIconButton(
              icon: Icons.delete_outline,
              color: ds.error,
              iconSize: 20,
              semanticLabel: l10n.downloadsDeleteBtn,
              onPressed: () => performDownloadAction(
                context,
                () => ref.read(downloadsProvider.notifier).deleteDownload(
                      downloadId,
                    ),
              ),
            ),
          ],
        );
      case DownloadStatus.pending:
        return AppIconButton(
          icon: Icons.cancel,
          semanticLabel: l10n.downloadCancel,
          onPressed: () => performDownloadAction(
            context,
            () => ref.read(downloadsProvider.notifier).cancelDownload(
                  downloadId,
                ),
          ),
        );
    }
  }
}
