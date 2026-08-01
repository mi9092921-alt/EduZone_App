import 'dart:io';

import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/entities/student_profile.dart';
import '../providers/profile_provider.dart';

/// Bottom sheet for editing profile name and avatar.
///
/// Pre-fills with current profile data. On save, calls
/// [ProfileActions.updateName] and optionally [ProfileActions.uploadAvatar].
class EditProfileBottomSheet extends ConsumerStatefulWidget {
  final StudentProfile profile;

  const EditProfileBottomSheet({super.key, required this.profile});

  @override
  ConsumerState<EditProfileBottomSheet> createState() =>
      _EditProfileBottomSheetState();

  /// Show the bottom sheet.
  static Future<void> show(BuildContext context, StudentProfile profile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => EditProfileBottomSheet(profile: profile),
    );
  }
}

class _EditProfileBottomSheetState
    extends ConsumerState<EditProfileBottomSheet> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  String? _selectedImagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(
      text: widget.profile.firstName ?? '',
    );
    _lastNameCtrl = TextEditingController(text: widget.profile.lastName ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() => _selectedImagePath = image.path);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);

    final actions = ref.read(profileActionsProvider.notifier);
    bool success = true;

    // Upload avatar if changed
    if (_selectedImagePath != null) {
      success = await actions.uploadAvatar(_selectedImagePath!);
    }

    // Update name if changed
    if (success) {
      final newFirst = _firstNameCtrl.text.trim();
      final newLast = _lastNameCtrl.text.trim();

      if (newFirst.isEmpty) {
        if (!mounted) return;
        AppSnackbar.showError(
          context: context,
          message:
              l10n.errorGeneric, // We can use a more specific one if available
        );
        setState(() => _isSaving = false);
        return;
      }

      final firstChanged = newFirst != (widget.profile.firstName ?? '');
      final lastChanged = newLast != (widget.profile.lastName ?? '');

      if (firstChanged || lastChanged) {
        success = await actions.updateName(
          firstName: firstChanged ? newFirst : null,
          lastName: lastChanged ? newLast : null,
        );
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Material(
            color: ds.border,
            borderRadius: BorderRadius.circular(2),
            child: const SizedBox(width: 40, height: 4),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Title
          Text(
            l10n.editProfile,
            style: AppTextStyles.h2.copyWith(color: ds.textPrimary),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Avatar with edit button
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                if (_selectedImagePath != null)
                  CircleAvatar(
                    radius: 44,
                    backgroundImage: FileImage(File(_selectedImagePath!)),
                  )
                else
                  AppAvatar(
                    url: widget.profile.avatarUrl,
                    name: widget.profile.displayName,
                    radius: 44,
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: ds.surface, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(AppIcons.camera, size: 14, color: ds.surface),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // First name field
          AppTextField(controller: _firstNameCtrl, label: l10n.firstName),

          const SizedBox(height: AppSpacing.lg),

          // Last name field
          AppTextField(controller: _lastNameCtrl, label: l10n.lastName),

          const SizedBox(height: AppSpacing.xl),

          // Save button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: l10n.saveChanges,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}
