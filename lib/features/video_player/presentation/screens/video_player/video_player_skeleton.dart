import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Loading-state layout shown (wrapped in [AppSkeleton]) while the course
/// or lesson content is still being fetched.
///
/// Extracted from `video_player_screen.dart`'s private
/// `_buildSkeletonLayout` method — purely presentational, no dependency
/// on [VideoPlayerScreen]'s state, so it's promoted to its own widget.
class VideoPlayerSkeleton extends StatelessWidget {
  const VideoPlayerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      scrollable: false,
      appBar: AppBar(
        elevation: 0,
        // check-ignore: no pure-black design token exists (v1); skeleton
        // placeholder surfaces intentionally stay neutral0/black.
        title: Container(
          width: 150, // no matching design token (v1)
          height: 20, // no matching design token (v1)
          color: AppColors.neutral0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            // check-ignore: no pure-black design token exists (v1).
            child: ColoredBox(color: Colors.black),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(height: AppSpacing.xl, color: AppColors.neutral0),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (_, i) => ListTile(
                leading: Container(
                  width: AppSpacing.xl3,
                  height: AppSpacing.xl3,
                  color: AppColors.neutral0,
                ),
                title: Container(
                  height: AppSpacing.lg,
                  color: AppColors.neutral0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
