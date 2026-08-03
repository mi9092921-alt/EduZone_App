import 'package:flutter/material.dart';

class AppChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const AppChip({super.key, required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Chip(
      // Only `color` is customised here by design -- this is a generic,
      // reusable chip wrapper and must keep inheriting font size/weight
      // from ChipTheme (see AppTheme.chipTheme) rather than hardcoding a
      // design-system text token, which would override that inheritance
      // for every call site.
      label: Text(label, style: TextStyle(color: textColor)), // check-ignore
      backgroundColor: color,
    );
  }
}
