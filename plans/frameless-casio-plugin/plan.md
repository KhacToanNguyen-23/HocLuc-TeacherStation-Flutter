# Plan: Chế Độ Hiển Thị Sát Viền Thân Máy (`frameless: true`) Cho Plugin Máy Tính Casio

**Date:** 2026-10-17
**Mode:** --fast
**Risk:** normal — Mở rộng thuộc tính `frameless` trong `PluginManifest`, bổ sung giao diện không viền (`frameless`) cho `FloatingPluginWindow` và CSS nhúng sát viền cho `plugins/casio_calculator`.
**Spec:** `plans/frameless-casio-plugin/spec.md`

---

## Scope Challenge & Spec Quality Check

```text
# Scope Challenge:
#   Exists?     → Chưa có cờ `frameless` trong `PluginManifest` và `FloatingPluginWindow`; giao diện Casio hiện còn hiển thị header `hocluc.com`, nền xám trắng `#edf1f5` và dòng bản quyền ở đáy.
#   Minimum?    → 1 Phase: (1) Bổ sung `frameless: true` vào `PluginManifest` & `FloatingPluginWindow` (gờ kéo tích hợp + nút đóng `×` trên thân máy), và (2) Bổ sung `ui/embed.css` + cập nhật `manifest.json` trong `plugins/casio_calculator` rồi đóng gói lại `casio_calculator.hlep`.
#   Complexity? → Fast (≤ 2 thành phần quen thuộc: Host Floating Widget + Casio Plugin CSS/Manifest)
#
# Mode: --fast
# Test: default
# Tasks: default

# Spec Quality Check:
#   [NEEDS CLARIFICATION] remaining? → 0
#   Success criteria measurable?     → PASS (0px viền trắng, kích thước khớp 328x556 bo góc 24px, 5/5 architecture_test PASS, 100% casio_calculator_e2e_test PASS)
#   User stories P1/P2/P3?           → PASS (3 P1 stories)
#   Acceptance criteria testable?    → PASS
#
# Verdict: PASS
```

---

## Cấu Trúc Triển Khai

| Phase | Tên Phase | Tệp Chỉnh Sửa / Tạo Mới |
| :--- | :--- | :--- |
| **Phase 01** | **Frameless Floating Host & Casio Bare-Device CSS** (`phase-01-frameless-device-host-and-casio-embed.md`) | `frontend/lib/models/plugin_manifest.dart`, `frontend/lib/services/plugin_marketplace_service.dart`, `frontend/lib/widgets/floating_plugin_window.dart`, `plugins/casio_calculator/manifest.json`, `plugins/casio_calculator/ui/embed.css`, `plugins/casio_calculator/ui/index.html`, `frontend/test/casio_calculator_e2e_test.dart` |

