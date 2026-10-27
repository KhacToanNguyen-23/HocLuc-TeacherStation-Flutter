# Plan: Live DOM SVG Extraction & Canva BoxTransform Engine

Mode: --auto  
Risk: normal — Flutter sticker transform decoupling & live DOM SVG extraction from WebView plugin.

## 1. Problem Statement & Scope Alignment
1. **Lỗi Object Manipulation & Crash Lần 2:**
   - Khi kéo hoặc xoay sticker, Flutter ném ra lỗi `shifted_box.dart: Failed assertion: line 111 pos 18: 'transformed == position - childParentData.offset': is not true`.
   - Nguyên nhân: `OverflowBox` nằm lồng bên trong `Transform.rotate` xung đột với ma trận tính toạ độ chuột của Flutter, làm sập Gesture Arena $\rightarrow$ chỉ kéo được đúng 1 lần, lần sau ấn ra ngoài hay bấm lại đều bị đơ hoàn toàn.
   - Thanh công cụ nổi (`[Ghim | Sửa | Xóa]`) bị xoay nghiêng ngả theo hình thay vì luôn nằm ngang như Canva/Figma.
2. **Lỗi Lệch Giao Diện do Tự Build Lại SVG:**
   - Math Studio gọi hàm render thứ 2 (`generateGraphSvg`) tự vẽ lại chuỗi SVG khi ghim lên bảng thay vì bê nguyên đối tượng DOM SVG mà JSXGraph đã render trong panel.

---

## 2. Phased Execution Roadmap

- [x] Phase 1: Live DOM SVG Extraction (Math Studio Plugin)
  - Detail: `plans/canva-object-manipulation-and-sync/phase-01-live-dom-svg-extraction.md`
- [x] Phase 2: Canva BoxTransform Engine & Crash Elimination (Flutter Native)
  - Detail: `plans/canva-object-manipulation-and-sync/phase-02-canva-box-transform-engine.md`
- [x] Phase 3: Verification & Architecture Gate
  - Detail: `plans/canva-object-manipulation-and-sync/phase-03-verification-and-architecture-gate.md`

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-26 14:41  
**Phase in progress:** Completed  
**Status:** All 3 phases implemented and verified. Zero assertion crash, decoupled horizontal action bar, inverse rotation mouse delta math, live DOM SVG extraction, and 12/12 Invariants PASS.

### Decisions made this session
- **Live DOM Extraction:** Added `exportLiveContainerSvg()` in `app.js` to clone and sanitize the active container's live SVG directly from the DOM, ensuring 100% visual fidelity with the panel. Set `text: { display: 'internal' }` in JSXGraph. Repackaged `plugins/math_studio.hlep`.
- **Decoupled Floating Action Bar:** Moved the Floating Action Bar completely outside `Transform.rotate` into an unrotated top sibling layer in `board_sticker_card.dart`. It stays horizontal (Canva/Figma standard) and never triggers `shifted_box.dart` assertion failures. Added top/bottom auto-flip if too close to the canvas top boundary.
- **Affine Transform Projection:** Implemented inverse rotation mouse delta projection $\Delta P_{local} = R(-\theta) \Delta P_{global}$ in `_handleCornerResize` and `_handleEdgeResize` with opposite-anchor pinning.
- **Continuous Lifecycle:** Verified seamless click-outside deselect and re-selection with zero freezes.
- **Architecture Gate:** Validated 12/12 Invariants PASS and 3/3 plugins valid Schema v2.1.
