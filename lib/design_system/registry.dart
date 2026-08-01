/// Design System Component Registry
///
/// This file serves as the single source of truth for discovering available
/// UI primitives within the application. Before creating any custom UI,
/// developers MUST check this registry.
///
/// TO ADD A COMPONENT:
/// 1. Create it in `components/<category>/`
/// 2. Export it in `design_system.dart`
/// 3. Document it in this registry.
library;

// 4. ACTION
export 'components/button/app_button.dart'; // Primary/Secondary Buttons
// 2. CONTAINERS
export 'components/card/app_card.dart'; // Standard surface container with tap animations
// 3. INPUT
export 'components/input/app_text_field.dart'; // Universal text fields
export 'components/layout/app_bottom_nav.dart'; // Glassmorphism bottom nav
export 'components/layout/app_modern_header.dart'; // Standard header component
// ==========================================
// 🎨 TOKENS
// ==========================================
// - AppColors: Primary, Secondary, Backgrounds, Status colors.
// - AppSpacing: xs(4), sm(8), md(16), lg(24), xl(32).
// - AppRadius: sm(8), md(16), lgBorder(32), etc.
// - AppTextStyles: h1->h3, bodyLarge->Small, button, overline.
// - AppElevation: sm, md, lg shadows.

// ==========================================
// 🧱 COMPONENTS
// ==========================================

// 1. LAYOUT
export 'components/layout/app_screen.dart'; // Universal Scaffold wrapper
export 'components/status/app_skeleton.dart'; // Modern Skeletonizer wrapper
// 5. STATUS
export 'components/status/app_status_dot.dart'; // Status/Priority dot with glow
