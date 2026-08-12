# Design System Lint Rules

Our governance heavily relies on lint rules and CI pipelines to prevent codebase fragmentation.

## CI Blockers
The `scripts/check_design_system.sh` explicitly rejects Pull Requests containing:
- `Container(` -> Use `SizedBox`, `Padding`, `AppScreen`, or `AppCard` instead.
- `BoxDecoration(` -> If a box needs decoration, it must belong in the `design_system`.
- `Colors.` -> Use `AppColors` tokens (`AppColors.primary`, etc.).
- `TextStyle(` -> Use `AppTextStyles` tokens (`AppTextStyles.bodyMedium`, etc.).

## analysis_options.yaml strictness
We extend `flutter_lints` with specific Dart rules to ensure structural consistency:
- `avoid_unnecessary_containers`: Flags `Container`s mapped to only sizing constraints.
- `sized_box_for_whitespace`: Forces standard memory-friendly empty space boxes over containers.
- `use_decorated_box`: Enforces semantics.
