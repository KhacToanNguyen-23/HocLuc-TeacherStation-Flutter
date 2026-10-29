# Plan: Ghim Đồ thị từ Native Plugin lên Bảng đen (Stamp Graph to Chalkboard)

Mode: Fast
Risk: tiny — 2 UI files in plugin_engine, fully reversible, no DB/auth/schema changes
Spec: plans/stamp-graph-to-board/spec.md
Brainstorm: plans/reports/261027-stamp-graph-to-board-brainstorm.md
Date: 2026-10-27

---

## Overview
Khi người dùng bấm "Ghim vào bảng" trên cửa sổ công cụ Native Plugin (QuickJS), `NativePluginHost` sẽ trích xuất trực tiếp buffer hiển thị của `NativeSceneCanvas` thông qua `RenderRepaintBoundary.toImage(pixelRatio: 2.0)` chuyển thành `imageBase64` (đối với Đồ thị 2D, Tích phân, Hình không gian 3D) hoặc truyền `svgContent` (đối với Bảng biến thiên BBT). Đảm bảo thẻ sticker trên bảng đen hiển thị đồ thị nguyên vẹn 100% khớp với màn hình công cụ, không tính toán lại hay sinh lại đồ thị.

---

## Phase Breakdown

### Phase 1: RepaintBoundary trên Canvas CustomPaint
- **File**: `plans/stamp-graph-to-board/phase-01-canvas-repaint-boundary.md`
- **Mục tiêu**: Thêm `GlobalKey` gắn vào `RepaintBoundary` bọc riêng phần `CustomPaint` của `NativeSceneCanvas`, tách biệt khỏi các nút floating toolbar điều khiển viewport.
- **Stories**: `stamp-graph-2d-3d-integral-snapshot` [P1]

### Phase 2: Chụp ảnh Snapshot và Đóng gói Sticker Dispatch
- **File**: `plans/stamp-graph-to-board/phase-02-host-snapshot-stamping.md`
- **Mục tiêu**: Cập nhật hàm `_stampToBoard()` trong `NativePluginHost` để chụp buffer thành PNG Base64 không đồng bộ và gửi đầy đủ payload hình ảnh/vector vào tin nhắn `board:insert_annotation`.
- **Stories**: `stamp-graph-2d-3d-integral-snapshot` [P1], `stamp-bbt-svg-vector` [P1], `canva-aspect-ratio-scale` [P2]

### Phase 3: Kiểm thử Tự động & Bảo vệ Kiến trúc
- **File**: `plans/stamp-graph-to-board/phase-03-verification.md`
- **Mục tiêu**: Chạy kiểm thử kiến trúc (12/12 invariants), kiểm tra tĩnh phân tích mã nguồn (`flutter analyze`), và xác thực plugin marketplace.
- **Stories**: Toàn bộ P1/P2

