import 'package:app/core/utils/text_direction_detector.dart';
import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../auth/domain/enums/account_status.dart';
import '../../domain/entities/student_profile.dart';

/// Displays the user's avatar, name, email, and account status.
///
/// Includes an edit button that triggers [onEditPressed].
class UserInfoCard extends StatelessWidget {
  final StudentProfile profile;
  final VoidCallback? onEditPressed;

  const UserInfoCard({super.key, required this.profile, this.onEditPressed});

  AccountStatus get _accountStatus => profile.accountStatus;

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      elevated: false,
      borderColor: ds.border,
      animateScale: false,
      child: Stack(
        children: [
          // Content Row
          Row(
            children: [
              // Avatar Section
              Stack(
                alignment: AlignmentDirectional.bottomEnd,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ds.primarySoft,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3), // check-ignore -- single-use precise avatar-ring inset, not a repeating pattern
                      child: AppAvatar(
                        url: profile.avatarUrl,
                        name: profile.displayName,
                        radius:
                            36, // Slightly smaller radius for horizontal layout
                      ),
                    ),
                  ),
                  if (onEditPressed != null)
                    Semantics(
                      button: true,
                      label: l10n.changeAvatar,
                      child: GestureDetector(
                        onTap: onEditPressed,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ds.primary,
                            border: Border.all(color: ds.surface, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs2), // check-ignore -- already a token; false positive
                            child: Icon(
                              AppIcons.camera,
                              size: 12,
                              color: ds.surface,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: AppSpacing.lg),

              // Name & Email Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.displayName,
                      textDirection: TextDirectionDetector.detect(profile.displayName),
                      style: AppTextStyles.h3.copyWith(
                        color: ds.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: profile.email));
                        if (context.mounted) {
                          AppSnackbar.showSuccess(
                            context: context,
                            message: l10n.emailCopied,
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              profile.email,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: ds.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.copy,
                            size: 12,
                            color: ds.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Top Corner Status Chip - Flips based on language (Right in LTR, Left in RTL)
          Positioned.directional(
            textDirection: Directionality.of(context),
            top: 0,
            end: 0,
            child: StatusChip(status: _accountStatus),
          ),
        ],
      ),
    );
  }
}