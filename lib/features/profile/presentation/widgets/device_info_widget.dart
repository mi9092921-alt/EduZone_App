import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../core/utils/device_info_helper.dart';

/// Displays the current device model and a "verified" chip.
///
/// Uses [DeviceInfoHelper.deviceModel] for the device name
/// and [DeviceInfoHelper.platform] for the platform icon.
class DeviceInfoWidget extends StatelessWidget {
  const DeviceInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: ds.surface,
      borderColor: ds.border,
      elevated: false,
      borderRadius: 12,
      child: Row(
        children: [
          // Device icon
          AppCard(
            padding: const EdgeInsets.all(10),
            backgroundColor: ds.surface2,
            elevated: false,
            borderRadius: 10,
            child: const Icon(
              AppIcons.device,
              color: AppColors.primary,
              size: 22,
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // Device info text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deviceInfo,
                  style: AppTextStyles.label.copyWith(
                    color: ds.textSecondary,
                    fontWeight: FontWeight
                        .w500, // Slight weight increase for "pale" issue
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DeviceInfoHelper.deviceModel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ds.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Verified chip
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            backgroundColor: AppColors.success.withValues(alpha: 0.1),
            borderColor: AppColors.success.withValues(alpha: 0.2),
            elevated: false,
            borderRadius: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  AppIcons.verified,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.verifiedDevice,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize:
                        10, // Slightly smaller but bolder for premium look
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
