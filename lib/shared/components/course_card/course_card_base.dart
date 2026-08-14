import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';

/// Shared layout card component providing transitions, hover effects,
/// tap handling, card borders, shadow levels, and layout structure (vertical/horizontal).
class CourseCardBase extends StatefulWidget {
  final Widget image;
  final Widget content;
  final bool isHorizontal;
  final VoidCallback? onTap;
  final double? verticalImageAspectRatio;
  final double horizontalHeight;
  final double horizontalImageWidth;
  final String semanticLabel;
  final EdgeInsetsGeometry? contentPadding;

  /// When true, the content area in vertical layout uses [Expanded] instead
  /// of [Flexible], giving bounded height so [Spacer] works correctly.
  final bool expandContent;

  const CourseCardBase({
    super.key,
    required this.image,
    required this.content,
    required this.semanticLabel,
    this.isHorizontal = false,
    this.onTap,
    this.verticalImageAspectRatio,
    this.horizontalHeight = 100,
    this.horizontalImageWidth = 95,
    this.contentPadding,
    this.expandContent = false,
  });

  @override
  State<CourseCardBase> createState() => _CourseCardBaseState();
}

class _CourseCardBaseState extends State<CourseCardBase> {
  bool _isHovered = false;
  bool _isPressed = false;

  double get _scale => _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _scale,
          duration: AppMotion.fast,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              // Lighter, more premium border weight (was 0.6).
              border: Border.all(color: colors.border.withValues(alpha: 0.35)),
              boxShadow: _isHovered || _isPressed
                  ? AppElevation.shadowMd
                  : AppElevation.shadowSm,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _isPressed = true),
                onTapUp: (_) => setState(() => _isPressed = false),
                onTapCancel: () => setState(() => _isPressed = false),
                child: widget.isHorizontal
                    ? _buildHorizontalLayout(colors)
                    : _buildVerticalLayout(colors),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(DesignSystemColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Tighter image padding frees up a little more room for content
          // (was AppSpacing.xs on all sides).
          padding: const EdgeInsets.all(AppSpacing.xs2), // check-ignore -- already a token; false positive (regex matches the digit in "xs2")
          child: AspectRatio(
            aspectRatio: widget.verticalImageAspectRatio ?? 2.0,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                // Lighter image border (was 0.4).
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.border.withValues(alpha: 0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: widget.image,
            ),
          ),
        ),
        if (widget.expandContent)
          Expanded(
            child: Padding(
              padding:
                  widget.contentPadding ??
                  const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.sm,
                    0,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
              child: widget.content,
            ),
          )
        else
          Flexible(
            child: Padding(
              padding:
                  widget.contentPadding ??
                  const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.sm,
                    0,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
              child: widget.content,
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontalLayout(DesignSystemColors colors) {
    return SizedBox(
      height: widget.horizontalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xs2), // check-ignore -- already a token; false positive (regex matches the digit in "xs2")
            child: SizedBox(
              width: widget.horizontalImageWidth,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.border.withValues(alpha: 0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: widget.image,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding:
                  widget.contentPadding ??
                  const EdgeInsetsDirectional.fromSTEB(
                    0,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
              child: widget.content,
            ),
          ),
        ],
      ),
    );
  }
}
