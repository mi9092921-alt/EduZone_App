import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../domain/entities/student_profile.dart';
import '../../application/providers/profile_provider.dart';
import '../widgets/device_info_widget.dart';
import '../widgets/edit_profile_bottom_sheet.dart';
import '../widgets/settings_section.dart';
import '../widgets/user_info_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(profileProvider);

    return AppPageScaffold(
      title: l10n.profileTab,
      centerTitle: true,
      onRetry: () => ref.invalidate(profileProvider),
      error: profileAsync.hasError ? l10n.errorGeneric : null,
      bottomSpacing: AppSpacing.xl4,
      slivers: [
        AppSkeleton.sliver(
          enabled: profileAsync.isLoading && !profileAsync.hasValue,
          child: profileAsync.when(
            loading: () =>
                _buildProfileContent(context, StudentProfile.skeleton()),
            error: (error, _) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (profile) => _buildProfileContent(context, profile),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileContent(BuildContext context, StudentProfile profile) {
    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // User Info Card
          UserInfoCard(
            profile: profile,
            onEditPressed: () {
              EditProfileBottomSheet.show(context, profile);
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // Device Info (Secondary importance)
          const DeviceInfoWidget(),

          const SizedBox(height: AppSpacing.md),

          // Settings Section
          const SettingsSection(),
        ]),
      ),
    );
  }
}
