import 'package:app/design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../domain/entities/auth_state.dart';
import '../../application/providers/auth_provider.dart';

/// Login screen with state-driven navigation per PRD §7.2.
///
/// Flow: validate form → auth.login() → state change → router redirects.
/// NO manual context.go() — the router's redirect handles all transitions.
class LoginScreen extends ConsumerStatefulWidget {
  final String? reason;

  const LoginScreen({super.key, this.reason});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String _appVersion = '';
  bool _agreedToTerms = false;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('${AppRoutes.legal}/terms');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('${AppRoutes.legal}/privacy');
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = packageInfo.version);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);
    final isLoading = authState is AuthAuthenticating || authState is AuthLoggingOut;
    final errorKey = authState is AuthUnauthenticated ? authState.error : null;

    return AppScreen(
      isLoading: isLoading,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.primaryGradient.createShader(bounds),
                    child: const Icon(
                      AppIcons.home,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n!.loginTitle,
                    style: AppTextStyles.h1.copyWith(
                      color: AppColors.onSurfacePrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.loginSubtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl2),

                  // Email field
                  AppTextField(
                    controller: _emailController,
                    label: l10n.emailHint,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.emailHint;
                      }
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return l10n.errorInvalidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Password field
                  AppTextField(
                    controller: _passwordController,
                    label: l10n.passwordHint,
                    prefixIcon: AppIcons.lock,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signIn(),
                    suffixIcon: IconButton(
                     tooltip: _obscurePassword ? l10n.passwordShow : l10n.passwordHide,
                      icon: Icon(
                        _obscurePassword
                            ? AppIcons.visibilityOff
                            : AppIcons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.passwordHint;
                      }
                      if (value.length < 8) {
                        return l10n.errorPasswordTooShort;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Terms Agreement
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _agreedToTerms,
                          activeColor: AppColors.primary,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.xxsBorder,
                          ),
                          onChanged: (value) =>
                              setState(() => _agreedToTerms = value ?? false),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              TextSpan(text: l10n.agreeToTermsPrefix),
                              TextSpan(
                                text: l10n.termsAndConditions,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _termsRecognizer,
                              ),
                              TextSpan(text: l10n.agreeToTermsMiddle),
                              TextSpan(
                                text: l10n.privacyPolicy,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _privacyRecognizer,
                              ),
                              TextSpan(text: l10n.agreeToTermsSuffix),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: l10n.loginButton,
                      variant: AppButtonVariant.gradient,
                      isLoading: isLoading,
                      onPressed: _signIn,
                    ),
                  ),

                  // Error message
                  if (errorKey != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        _getErrorMessage(errorKey, l10n),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: AppSpacing.xl2),
                  // Version Footer
                  if (_appVersion.isNotEmpty)
                    Text(
                      '${l10n.appTitle} ${l10n.versionLabel(_appVersion)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Login flow — State-Driven (no manual navigation).
  ///
  /// 1. Client-side validation
  /// 2. auth.login() sets AuthState
  /// 3. Router redirect picks up the state change and navigates
  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;

    if (!_agreedToTerms) {
      AppSnackbar.showError(context: context, message: l10n.agreeToTermsError);
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (ref.read(authProvider) is AuthAuthenticating) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // State change here drives router navigation automatically.
    // No context.go() needed — the router redirect handles everything.
    await ref.read(authProvider.notifier).login(email, password);
  }

  /// Maps error keys from AuthNotifier to localized user-facing messages.
  String _getErrorMessage(String errorKey, AppLocalizations l10n) {
    if (errorKey == 'emulator_blocked') {
      return l10n.errorEmulatorBlocked;
    }
    if (errorKey == 'errorEmailNotConfirmed') {
      return l10n.errorEmailNotConfirmed;
    }
    if (errorKey == 'errorAuth') {
      return l10n.errorAuth;
    }
    if (errorKey == 'errorNetwork') {
      return l10n.errorNetwork;
    }
    if (errorKey.startsWith('errorRateLimit')) {
      final parts = errorKey.split(':');
      final seconds = parts.length > 1 ? int.tryParse(parts[1]) ?? 300 : 300;
      final minutes = (seconds / 60).ceil();
      return l10n.errorRateLimit(minutes);
    }
    if (errorKey == 'errorMaxDevices') {
      return l10n.errorMaxDevices;
    }
    if (errorKey == 'errorDeviceBound') {
      return l10n.errorDeviceBound;
    }
    return l10n.errorGeneric;
  }
}
