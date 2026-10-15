# Plan: High-End UI Cleanup, Compact Standalone Login & Room Creation Dialog

Mode: --fast
Risk: normal — touches Flutter UI presentation layers, zero backend or database impact

## Overview
Refactor the UI following high-end visual design principles:
1. Update room creation dialog loading text to **"Đang tạo phòng..."** (replacing "Đang chuẩn bị phòng Google Meet...").
2. Re-architect the Login Screen from a 50/50 split hero layout to an elegant, compact standalone desktop window card with double-bezel styling.
3. Audit and eliminate redundant UI descriptions and emoji icons across the dashboard and studio widgets, replacing them with crisp line icons and title-first typography.

## Phases

- [x] Phase 1: Room Creation Dialog Text & Dashboard Descriptions Cleanup
- [x] Phase 2: Compact Standalone Desktop Window Login Screen
- [x] Phase 3: Sweep Emoji Icons & Final Visual Verification

## File Ownership
- `frontend/lib/screens/classroom_dashboard_screen.dart`
- `frontend/lib/widgets/dashboard/exam_dashboard_card.dart`
- `frontend/lib/screens/login_screen.dart`
- `frontend/lib/widgets/studio/studio_student_strip.dart`
- `frontend/lib/widgets/studio/studio_students_drawer.dart`
- `frontend/lib/widgets/studio/studio_meet_cockpit_tab.dart`
- `frontend/lib/widgets/studio/studio_inspector_panel.dart`
- `frontend/lib/widgets/pdf_dgnl_passage_overlay.dart`
- `frontend/lib/widgets/floating_pip.dart`
- `frontend/lib/services/plugin_manager.dart`

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-15 12:16
**Phase in progress:** All phases complete
**Status:** Completed with 100% test pass rate across all suites

### Decisions made this session
- Replaced loading dialog text 'Đang chuẩn bị phòng Google Meet...' with clean, direct 'Đang tạo phòng...'.
- Redesigned LoginScreen into a 440px compact standalone desktop window card with squircle outer border, subtle ambient diffuse shadow, and window header.
- Stripped verbose subtitle descriptions (e.g. V-ACT/HSA card description) on Dashboard for a clean title-first agency layout.
- Swept all emoji characters (✋, 💡, 📌, 🎯, ⚡, 🔤, 🇬🇧) across Studio and overlays, replacing them with vector outline icons.
