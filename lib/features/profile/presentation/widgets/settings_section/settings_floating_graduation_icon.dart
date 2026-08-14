import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Gently pulsing graduation-cap icon shown at the top of the "About"
/// dialog. Fully self-contained animation — no dependency on any parent
/// state, so it moves out unchanged.
class SettingsFloatingGraduationIcon extends StatefulWidget {
  const SettingsFloatingGraduationIcon({super.key});

  @override
  State<SettingsFloatingGraduationIcon> createState() =>
      _SettingsFloatingGraduationIconState();
}

class _SettingsFloatingGraduationIconState
    extends State<SettingsFloatingGraduationIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.shimmer,
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
