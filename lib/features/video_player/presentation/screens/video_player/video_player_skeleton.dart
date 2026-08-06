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
        title: Container(width: 150, height: 20, color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(height: 24, color: Colors.white),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (_, i) => ListTile(
                leading: Container(width: 40, height: 40, color: Colors.white),
                title: Container(height: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
