import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_providers.dart';
import '../../../../app/state/app_state_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../core/permissions/permission_builder.dart';
import '../../../../core/permissions/permission_item.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'adaptive_settings_picker.dart';
import 'settings_tile.dart';

class SettingsSection extends ConsumerStatefulWidget {
  const SettingsSection({super.key});

  @override
  ConsumerState<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<SettingsSection> {
  bool _permissionsLoading = true;
  String _appVersion = '1.0.0';
  Locale? _lastLocale;
  List<PermissionItem> _permissionItems = const [];
  Map<AppPermissionKind, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadAppPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final locale = Localizations.localeOf(context);
    if (_lastLocale != locale) {
      _lastLocale = locale;
      _loadPermissions();
    }
  }

  Future<void> _loadAppPreferences() async {
    final packageInfo = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _loadPermissions() async {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    if (mounted) {
      setState(() => _permissionsLoading = true);
    }

    final items = await buildPermissionItems(l10n: l10n);
    final statuses = await ref
        .read(permissionServiceProvider)
        .checkAllValues(items);

    if (!mounted) return;

    setState(() {
      _permissionItems = items;
      _permissionStatuses = statuses;
      _permissionsLoading = false;
    });
  }

  Future<void> _requestPermission(PermissionItem item) async {
    final status = await ref
        .read(permissionServiceProvider)
        .request(item.permission);

    if (!mounted) return;

    setState(() {
      _permissionStatuses[item.kind] = status;
    });

    if (status.isPermanentlyDenied) {
      await _showPermanentlyDeniedDialog(item);
    }
  }

  Future<void> _showPermanentlyDeniedDialog(PermissionItem item) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmDialog(
        title: l10n.permDeniedTitle,
        description: l10n.permDeniedMsg(item.label),
        confirmLabel: l10n.permActionOpenSettings,
        cancelLabel: l10n.closeButton,
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final opened = await ref
            .read(permissionServiceProvider)
            .openAppSettings();

        if (!opened && mounted) {
          // Fallback: Show manual instruction snackbar
          AppSnackbar.showError(
            context: context,
            message: l10n.permOpenSettingsManual,
          );
        }
      } catch (e) {
        if (mounted) {
          debugPrint('[SettingsSection] Failed to open app settings: $e');
          AppSnackbar.showError(
            context: context,
            message: l10n.permOpenSettingsError,
          );
        }
      }
    }
  }

  String _getPermissionStatusLabel(
    AppPermissionKind kind,
    AppLocalizations l10n,
  ) {
    final status = _permissionStatuses[kind] ?? PermissionStatus.denied;
    if (status.isGranted) return l10n.permissionGranted;
    if (status.isPermanentlyDenied) return l10n.permissionPermanentlyDenied;
    return l10n.permissionDenied;
  }



  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmDialog(
        title: l10n.logoutConfirmTitle,
        description: l10n.logoutConfirmMsg,
        confirmLabel: l10n.logout,
        cancelLabel: l10n.closeButton,
        isDangerous: true,
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  Future<void> _handleLinkTap(String? link, String errorMessage) async {
    if (link == null || link.isEmpty) {
      if (mounted) {
        AppSnackbar.showError(context: context, message: errorMessage);
      }
      return;
    }

    try {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        AppSnackbar.showError(context: context, message: errorMessage);
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context: context, message: errorMessage);
      }
    }
  }

  void _showAboutDialog(BuildContext context, String version) {
    final ds = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: scheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const _FloatingGraduationIcon(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.appTitle,
                style: AppTextStyles.h2.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                version,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: ds.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.modernLearningPlatform,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: ds.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.copyrightFull(DateTime.now().year.toString()),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: ds.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: l10n.ok,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final ds = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    final currentLanguage = locale.languageCode == 'ar' ? 'العربية' : 'English';
    final currentTheme = _getThemeLabel(themeMode, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.settings),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          elevated: false,
          backgroundColor: scheme.surface,
          borderColor: scheme.outlineVariant,
          child: Column(
            children: [
              Builder(
                builder: (tileContext) => SettingsTile(
                  icon: AppIcons.theme,
                  title: l10n.themeLabel,
                  subtitle: currentTheme,
                  semanticsLabel: '${l10n.themeLabel}, $currentTheme',
                  trailing: _ValueDisplay(value: currentTheme),
                  onTap: () => _showThemePicker(tileContext, themeMode, l10n),
                ),
              ),
              _divider(scheme.outlineVariant),
              Builder(
                builder: (tileContext) => SettingsTile(
                  icon: AppIcons.language,
                  title: l10n.languageLabel,
                  subtitle: currentLanguage,
                  semanticsLabel: '${l10n.languageLabel}, $currentLanguage',
                  trailing: _ValueDisplay(value: currentLanguage),
                  onTap: () => _showLanguagePicker(tileContext, locale, l10n),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(title: l10n.permissionsHeader),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          elevated: false,
          backgroundColor: scheme.surface,
          borderColor: scheme.outlineVariant,
          child: _buildPermissionsCard(l10n, scheme),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(title: l10n.supportAndInfo),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          elevated: false,
          backgroundColor: scheme.surface,
          borderColor: scheme.outlineVariant,
          child: Column(
            children: [
              SettingsTile(
                icon: AppIcons.support,
                title: l10n.helpAndSupport,
                trailing: _forwardIcon(ds),
                onTap: () => _handleLinkTap(
                  'https://eduzone.com/support',
                  l10n.errorLinkUnavailable,
                ),
              ),
              _divider(scheme.outlineVariant),
              SettingsTile(
                icon: Icons.thumb_up_rounded,
                title: l10n.followUs,
                trailing: _forwardIcon(ds),
                onTap: () => _handleLinkTap(
                  'https://eduzone.com/eduzone',
                  l10n.errorLinkUnavailable,
                ),
              ),
              _divider(scheme.outlineVariant),
              SettingsTile(
                icon: Icons.description_rounded,
                title: l10n.termsAndConditions,
                trailing: _forwardIcon(ds),
                onTap: () => context.push('${AppRoutes.legal}/terms'),
              ),
              _divider(scheme.outlineVariant),
              SettingsTile(
                icon: Icons.privacy_tip_rounded,
                title: l10n.privacyPolicy,
                trailing: _forwardIcon(ds),
                onTap: () => context.push('${AppRoutes.legal}/privacy'),
              ),
              _divider(scheme.outlineVariant),
              SettingsTile(
                icon: AppIcons.info,
                title: l10n.about,
                trailing: _forwardIcon(ds),
                onTap: () => _showAboutDialog(
                  context,
                  '${l10n.appTitle} ${l10n.versionLabel(_appVersion)}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Consumer(
          builder: (context, ref, _) {
            final appState = ref.watch(appStateProvider);
            final isLoggingOut = appState == AppAuthState.loggingOut;

            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoggingOut ? null : _handleLogout,
                icon: isLoggingOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Icon(AppIcons.logout, size: 18),
                label: Text(isLoggingOut ? l10n.loggingOut : l10n.logout),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            '${l10n.appTitle} ${l10n.versionLabel(_appVersion)}',
            style: AppTextStyles.bodySmall.copyWith(color: ds.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsCard(AppLocalizations l10n, ColorScheme scheme) {
    if (_permissionsLoading && _permissionItems.isEmpty) {
      return AppSkeleton(
        child: Column(
          children: List.generate(
            3,
            (index) => const SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Permission',
         //   subtitle: 'Permission description',
              trailing: _ValueDisplay(value: 'Denied'),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < _permissionItems.length; index++) ...[
          SettingsTile(
            icon: _iconForPermission(_permissionItems[index].kind),
            title: _permissionItems[index].label,
         // subtitle: _permissionItems[index].description,
            semanticsLabel:
                '${_permissionItems[index].label}, ${_getPermissionStatusLabel(_permissionItems[index].kind, l10n)}',
            trailing: _ValueDisplay(
              value: _getPermissionStatusLabel(
                _permissionItems[index].kind,
                l10n,
              ),
            ),
            onTap: () => _requestPermission(_permissionItems[index]),
          ),
          if (index != _permissionItems.length - 1)
            _divider(scheme.outlineVariant),
        ],
      ],
    );
  }

  Widget _divider(Color borderColor) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: AppSpacing.md,
      color: borderColor.withValues(alpha: 0.5),
    );
  }

  String _getThemeLabel(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
      case ThemeMode.system:
        return l10n.themeSystem;
    }
  }

  void _showThemePicker(
    BuildContext context,
    ThemeMode current,
    AppLocalizations l10n,
  ) {
    showSettingPicker<ThemeMode>(
      context: context,
      title: l10n.themeLabel,
      cancelLabel: l10n.cancel,
      currentValue: current,
      options: [
        SettingPickerOption(
          value: ThemeMode.light,
          label: l10n.themeLight,
          icon: AppIcons.lightMode,
        ),
        SettingPickerOption(
          value: ThemeMode.dark,
          label: l10n.themeDark,
          icon: AppIcons.darkMode,
        ),
        SettingPickerOption(
          value: ThemeMode.system,
          label: l10n.themeSystem,
          icon: Icons.settings_brightness_rounded,
        ),
      ],
      onSelected: (mode) {
        ref.read(appThemeModeProvider.notifier).updateTheme(mode);
      },
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    Locale current,
    AppLocalizations l10n,
  ) {
    showSettingPicker<Locale>(
      context: context,
      title: l10n.languageLabel,
      cancelLabel: l10n.cancel,
      currentValue: current,
      options: const [
        SettingPickerOption(
          value: Locale('ar'),
          label: 'العربية',
          icon: Icons.language_rounded,
        ),
        SettingPickerOption(
          value: Locale('en'),
          label: 'English',
          icon: Icons.language_rounded,
        ),
      ],
      onSelected: (locale) {
        ref.read(appLocaleProvider.notifier).updateLocale(locale);
      },
    );
  }

  IconData _iconForPermission(AppPermissionKind kind) {
    switch (kind) {
      case AppPermissionKind.location:
        return Icons.location_on_rounded;
      case AppPermissionKind.camera:
        return Icons.camera_alt_rounded;
      case AppPermissionKind.media:
        return Icons.photo_library_rounded;
      case AppPermissionKind.notifications:
        return AppIcons.notification;
    }
  }

  Widget _forwardIcon(DesignSystemColors ds) {
    return Icon(AppIcons.arrowForward, size: 16, color: ds.textSecondary);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: AppTextStyles.h3.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ValueDisplay extends StatelessWidget {
  const _ValueDisplay({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(color: ds.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Icon(
          AppIcons.arrowForward,
          size: 14,
          color: ds.textSecondary.withValues(alpha: 0.6),
        ),
      ],
    );
  }
}

class _FloatingGraduationIcon extends StatefulWidget {
  const _FloatingGraduationIcon();

  @override
  State<_FloatingGraduationIcon> createState() =>
      _FloatingGraduationIconState();
}

class _FloatingGraduationIconState extends State<_FloatingGraduationIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: FaIcon(
        FontAwesomeIcons.graduationCap,
        size: 36,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
