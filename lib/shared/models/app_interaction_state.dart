import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_interaction_state.freezed.dart';

/// A structured state for representing user interactions (hover, focus, press).
/// Used to maintain cross-platform UI consistency and accessibility.
@freezed
abstract class AppInteractionState with _$AppInteractionState {
  const factory AppInteractionState({
    @Default(false) bool isHovered,
    @Default(false) bool isFocused,
    @Default(false) bool isPressed,
    @Default(false) bool isDisabled,
  }) = _AppInteractionState;
}
