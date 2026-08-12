import 'package:app/core/utils/text_direction_detector.dart';
import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final bool readOnly;
  final bool isRTL;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final int? maxLines;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  /// Task 2: Optional auto-expand up to [maxExpandedLines] when true.
  final bool autoExpand;

  /// Task 2: Maximum lines to grow to when [autoExpand] is true (defaults to 4).
  final int maxExpandedLines;

  /// Task 2: Auto-detect RTL/LTR text direction from typed content when true.
  final bool autoDetectDirection;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.readOnly = false,
    this.isRTL =
        false, // If true, handled externally by Directionality, but left here for manual override.
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLines = 1,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.autoExpand = false,
    this.maxExpandedLines = 4,
    this.autoDetectDirection = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      widget.controller?.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (widget.autoDetectDirection && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.controller?.text ?? '';
    final TextDirection ambientDir = Directionality.of(context);

    final TextDirection resolvedDir;
    if (widget.isRTL) {
      resolvedDir = TextDirection.rtl;
    } else if (widget.autoDetectDirection) {
      resolvedDir = TextDirectionDetector.detect(text, fallback: ambientDir);
    } else {
      resolvedDir = ambientDir;
    }

    final bool resolvedRtl = resolvedDir == TextDirection.rtl;

    return TextFormField(
      controller: widget.controller,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      keyboardType: widget.autoExpand
          ? (widget.keyboardType ?? TextInputType.multiline)
          : widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      minLines: widget.autoExpand ? 1 : null,
      maxLines: widget.autoExpand ? widget.maxExpandedLines : widget.maxLines,
      // No explicit textAlign needed: TextAlign.start is already the
      // TextFormField default, and it resolves correctly here because
      // `textDirection` (below) is already explicitly set from resolvedDir.
      textDirection: resolvedRtl ? TextDirection.rtl : TextDirection.ltr,
      style: resolvedRtl
          ? AppTextStyles.bodyMediumAr
          : AppTextStyles.bodyMedium,
      obscureText: widget.obscureText,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, size: 20) : null,
        suffixIcon: widget.suffixIcon,
        filled:
            widget.readOnly || Theme.of(context).inputDecorationTheme.filled == true,
        fillColor: widget.readOnly
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).inputDecorationTheme.fillColor,
      ),
    );
  }
}
