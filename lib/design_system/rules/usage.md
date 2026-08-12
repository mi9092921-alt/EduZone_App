# Usage Guidelines

## Rule 1: Feature = Composition
Features (e.g., `features/home`) are strictly compositional logic mapping components together with data providers. 
They NEVER invent raw visual layouts manually.

## Rule 2: Token Dependency Only
Values like `BorderRadius.circular(16)` or `EdgeInsets.all(20)` are strictly banned from feature folders. Use `AppRadius.md` or `AppSpacing.xl`.

## Rule 3: Use the Universal Wrapper
ALL top-level routed screens must return an `AppScreen()`. This enforces safety in sets and universal page transition parameters seamlessly without fragmented `Scaffold` configurations globally.

## Rule 4: Design System is Closed
If you need a stylistic combination that doesn't exist in `AppCard` or `AppButton` variants, DO NOT override it locally using raw primitives. You must define a new `Variant` inside the design system layer itself for the team to reuse.
