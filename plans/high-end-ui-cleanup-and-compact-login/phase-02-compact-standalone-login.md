# Phase 2: Compact Standalone Login Window

## Objectives
1. Refactor `frontend/lib/screens/login_screen.dart`:
   - Eliminate the 50/50 split with `AuthHeroPanel`.
   - Render a centered, standalone desktop window card with fixed width (~420px).
   - Apply high-end double-bezel styling:
     - Outer container with soft diffuse ambient shadow (`BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 32, offset: Offset(0, 12))`).
     - Subtle hairline border (`0xFFE2E8F0`).
     - Refined header with application title/badge and clean spacing.
2. Ensure `AuthFormCard` integrates seamlessly into this standalone window without unnecessary inner padding or overflow issues.

## Verification
- Code review diff.
- Run `flutter analyze` or flutter tests.
