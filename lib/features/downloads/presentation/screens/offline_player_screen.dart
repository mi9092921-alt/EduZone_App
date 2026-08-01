import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/download_enums.dart';
import '../../presentation/providers/downloads_provider.dart';
import '../widgets/offline_player_wrapper.dart';

/// Screen for playing a downloaded (encrypted) lesson offline.
///
/// Looks up the [DownloadedLesson] by [downloadId], validates it is
/// still in [DownloadStatus.completed] state, and delegates rendering
/// to [OfflinePlayerWrapper].
class OfflinePlayerScreen extends ConsumerStatefulWidget {
  final String downloadId;

  const OfflinePlayerScreen({super.key, required this.downloadId});

  @override
  ConsumerState<OfflinePlayerScreen> createState() =>
      _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends ConsumerState<OfflinePlayerScreen> {
  bool _isFullScreen = false;
  bool _isVertical = false;

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final downloadAsync = ref.watch(downloadByIdProvider(widget.downloadId));

    return downloadAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(elevation: 0),
        body: Center(
          child: Text(
            l10n.errorGeneric,
            style: AppTextStyles.bodyMedium.copyWith(color: ds.error),
          ),
        ),
      ),
      data: (download) {
        if (download == null) {
          return Scaffold(
            appBar: AppBar(elevation: 0),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done_rounded, size: 64, color: ds.textSecondary),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.downloadNotFound,
                    style: AppTextStyles.h3.copyWith(color: ds.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }

        if (download.status != DownloadStatus.completed) {
          return Scaffold(
            appBar: AppBar(elevation: 0, title: Text(download.title)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 64, color: ds.textSecondary),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.downloadNotReady,
                    style: AppTextStyles.h3.copyWith(color: ds.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }

        final playerWidget = OfflinePlayerWrapper(
          download: download,
          isFullScreen: _isFullScreen,
          isVertical: _isVertical,
          onToggleFullScreen: () => setState(() => _isFullScreen = !_isFullScreen),
        );

        if (_isFullScreen) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: playerWidget,
          );
        }

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Text(download.title, style: AppTextStyles.h3),
          ),
          body: Column(
            children: [
              playerWidget,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 18, color: ds.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.offlineModeLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: ds.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    AppIconButton(
                      icon: _isVertical
                          ? Icons.crop_portrait_rounded
                          : Icons.crop_landscape_rounded,
                      semanticLabel: l10n.toggleAspectRatioTooltip,
                      onPressed: () => setState(() => _isVertical = !_isVertical),
                      backgroundColor: ds.surface2,
                      padding: const EdgeInsets.all(8),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppIconButton(
                      icon: Icons.fullscreen_rounded,
                      semanticLabel: l10n.fullScreenButtonTooltip,
                      onPressed: () => setState(() => _isFullScreen = !_isFullScreen),
                      backgroundColor: ds.surface2,
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
