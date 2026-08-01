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
      color: Color(0x4D000000), // black with 0.3 alpha
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
