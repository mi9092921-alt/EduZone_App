import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/app_providers.dart';
import '../../../../../app/state/app_state_provider.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../core/permissions/permission_builder.dart';
import '../../../../../core/permissions/permission_item.dart';
import '../../../../../core/services/permission_service.dart';
import '../../../../../shared/cross_feature/auth_shared.dart';
import '../../../../../shared/services/push_token_registration_service.dart';
import '../../../../../shared/utils/app_snackbar.dart';
import '../../../../../shared/widgets/confirm_dialog.dart';
import '../../../../auth/domain/entities/auth_state.dart';
import '../adaptive_settings_picker.dart';
import '../settings_tile.dart';
import 'settings_about_dialog.dart';
import 'settings_divider.dart';
import 'settings_permissions_card.dart';
import 'settings_section_header.dart';
import 'settings_theme_label.dart';
import 'settings_value_display.dart';

/// Structure note: state management (app-version loading, permissions
/// loading/requesting, logout, external-link handling) stays in this
/// file — it's one cohesive unit driven by `setState`/`mounted`, and
/// minimizing behavioral risk matters more than file length. The purely
/// presentational pieces (section header, value display, about dialog,
/// permissions card, floating icon) and the pure utility functions (theme
/// label, permission icon/status label) have been extracted into sibling
/// files in this folder — each independently testable with no dependency
/// on this State class.
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

    if (item.kind == AppPermissionKind.notifications && status.isGranted) {
      await PushTokenRegistrationService.requestPermissionAndRegister();
    }

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
          debugPrint(
            '[SettingsSection] Failed to open app settings: '
            '${e.runtimeType}',
          );
          AppSnackbar.showError(
            context: context,
            message: l10n.permOpenSettingsError,
          );
        }
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final ds = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    final currentLanguage = locale.languageCode == 'ar' ? 'العربية' : 'English';
    final currentTheme = themeModeLabel(themeMode, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(title: l10n.settings),
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
                  trailing: SettingsValueDisplay(value: currentTheme),
                  onTap: () => _showThemePicker(tileContext, themeMode, l10n),
                ),
              ),
              SettingsDivider(color: scheme.outlineVariant),
              Builder(
                builder: (tileContext) => SettingsTile(
                  icon: AppIcons.language,
                  title: l10n.languageLabel,
                  subtitle: currentLanguage,
                  semanticsLabel: '${l10n.languageLabel}, $currentLanguage',
                  trailing: SettingsValueDisplay(value: currentLanguage),
                  onTap: () => _showLanguagePicker(tileContext, locale, l10n),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSectionHeader(title: l10n.permissionsHeader),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          elevated: false,
          backgroundColor: scheme.surface,
          borderColor: scheme.outlineVariant,
          child: SettingsPermissionsCard(
            isLoading: _permissionsLoading,
            items: _permissionItems,
            statuses: _permissionStatuses,
            onRequestPermission: _requestPermission,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSectionHeader(title: l10n.supportAndInfo),
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
              SettingsDivider(color: scheme.outlineVariant),
              SettingsTile(
                icon: Icons.thumb_up_rounded,
                title: l10n.followUs,
                trailing: _forwardIcon(ds),
                onTap: () => _handleLinkTap(
                  'https://eduzone.com/eduzone',
                  l10n.errorLinkUnavailable,
                ),
              ),
              SettingsDivider(color: scheme.outlineVariant),
              SettingsTile(
                icon: Icons.description_rounded,
                title: l10n.termsAndConditions,
                trailing: _forwardIcon(ds),
                onTap: () => context.push('${AppRoutes.legal}/terms'),
              ),
              SettingsDivider(color: scheme.outlineVariant),
              SettingsTile(
                icon: Icons.privacy_tip_rounded,
                title: l10n.privacyPolicy,
                trailing: _forwardIcon(ds),
                onTap: () => context.push('${AppRoutes.legal}/privacy'),
              ),
              SettingsDivider(color: scheme.outlineVariant),
              SettingsTile(
                icon: AppIcons.info,
                title: l10n.about,
                trailing: _forwardIcon(ds),
                onTap: () => showSettingsAboutDialog(
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
          label: 'العربية', // check-ignore
          icon: Icons.language_rounded,
        ),
        SettingPickerOption(
          value: Locale('en'),
          label: 'English', // check-ignore
          icon: Icons.language_rounded,
        ),
      ],
      onSelected: (locale) {
        ref.read(appLocaleProvider.notifier).updateLocale(locale);
      },
    );
  }

  Widget _forwardIcon(DesignSystemColors ds) {
    return Icon(AppIcons.arrowForward, size: 16, color: ds.textSecondary);
  }
}
