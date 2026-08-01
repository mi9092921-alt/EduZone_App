import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/arb/app_localizations.dart';
import '../core/logging/logging_providers.dart';
import '../design_system/tokens/app_theme.dart';
import '../shared/utils/app_snackbar.dart';
import '../shared/widgets/network_banner.dart';
import 'app_providers.dart';
import 'router/app_router.dart';

class EduZoneApp extends ConsumerWidget {
  const EduZoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    // Bootstraps the enterprise logging system pipeline
    ref.watch(eventDispatcherProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'EduZone',
      scaffoldMessengerKey: FeedbackService.messengerKey,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(locale),
      darkTheme: AppTheme.dark(locale),
      themeMode: themeMode,
      builder: (context, child) => NetworkBanner(child: child!),
    );
  }
}
