import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../design_system/design_system.dart';

// Full-page spinner loading
class PageLoading extends StatelessWidget {
  const PageLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: AppColors.primary),
  );
}

// Generic skeleton card placeholder
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Bone.button(
      height: 120,
      width: double.infinity,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
  }
}
