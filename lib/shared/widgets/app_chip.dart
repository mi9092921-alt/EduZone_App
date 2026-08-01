import 'package:flutter/material.dart';

class AppChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const AppChip({super.key, required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: TextStyle(color: textColor)),
      backgroundColor: color,
    );
  }
}
