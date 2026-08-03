import 'package:app/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class AppFullScreenLoader extends StatelessWidget {
  const AppFullScreenLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: Key('full_screen_loader_bg'),
      color: AppColors.scrim, // black @ 30% alpha
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
