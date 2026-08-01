import 'package:flutter/material.dart';

import '../../core/l10n/arb/app_localizations.dart';
import '../../design_system/design_system.dart';

class ExpandableDescription extends StatefulWidget {
  final String text;
  final DesignSystemColors ds;
  final AppLocalizations l10n;
  final int maxLines;
  final int minLengthToExpand;

  const ExpandableDescription({
    super.key,
    required this.text,
    required this.ds,
    required this.l10n,
    this.maxLines = 3,
    this.minLengthToExpand = 150,
  });

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > widget.minLengthToExpand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: widget.ds.textSecondary,
            height: 1.6,
          ),
          maxLines: _isExpanded ? null : widget.maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                _isExpanded ? widget.l10n.showLess : widget.l10n.showMore,
                style: AppTextStyles.labelSmall.copyWith(
                  color: widget.ds.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
