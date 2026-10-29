# Phase 04: Vietnamese 3D Geometry Problem Parser (`geometry_parser.js`) & Dual-Theme Chalkboard Exporter

## Objective
Fix the invisible 3D geometry export on the dark chalkboard and empower teachers to either pick standard 3D SGK models or paste/type a Vietnamese 3D geometry problem statement to automatically generate the exact 3D textbook figure with altitude, right-angle markers, midpoints, and dashed hidden lines.

## Files to Create / Modify
1. **[NEW] `plugins/math_studio/ui/core/geometry_parser.js`**
   - Implement a fast, deterministic Vietnamese Geometry Problem Parser (`parseGeometryProblem(text, fallbackPreset)`):
     - **Base Solid Detection**:
       - `chóp tam giác đều` / `tứ diện đều` $\to$ `pyramid_tri_reg` (altitude $SO \perp (ABC)$ at centroid $O$)
       - `chóp tứ giác đều` $\to$ `pyramid_quad_reg` (altitude $SO \perp (ABCD)$ at intersection $O = AC \cap BD$)
       - `chóp S.ABC` / `tứ diện` $\to$ `pyramid_tri` (default $SA \perp (ABC)$ at back-left vertex $A$)
       - `chóp S.ABCD` $\to$ `pyramid_quad` (default $SA \perp (ABCD)$ at back-left vertex $A$)
       - `lăng trụ` $\to$ `prism_tri` ($ABC.A'B'C'$)
       - `hình hộp` / `lập phương` $\to$ `box_quad` ($ABCD.A'B'C'D'$)
       - `hình nón` $\to$ `cone`, `hình trụ` $\to$ `cylinder`, `mặt cầu` / `khối cầu` $\to$ `sphere`
     - **Altitude & Perpendicularity Rules**:
       - Detects `<X><Y> vuông góc với đáy` / `<X><Y> ⊥` (e.g. `SA ⊥ (ABCD)`), or `mặt bên (SAB) vuông góc với đáy` (altitude $SH \perp AB$ at midpoint $H$ of $AB$), or `SO vuông góc với đáy` (center $O$ of base), automatically adding a 3D right-angle marker (`∟`) at the altitude foot!
     - **Auxiliary Points & Segments Construction**:
       - Midpoints: `Gọi M là trung điểm của SC` / `M, N lần lượt là trung điểm của SA và BC` $\to$ computes exact 3D midpoint coordinates, labels $M, N$, and connects referenced segments.
       - Centroids: `G là trọng tâm tam giác SBC` $\to$ computes $(S+B+C)/3$.
       - Orthogonal Projections: `H là hình chiếu vuông góc của A lên SB` / `AH ⊥ SB` $\to$ computes exact projection of $A$ onto line $SB$, draws segment $AH$, and adds right-angle marker at $H$.
       - Planes/Sections: `(AMN)` / `(AHK)` $\to$ connects the polygon and applies a subtle translucent section fill.
     - Returns a clean human-readable Vietnamese title (e.g. `Hình chóp S.ABCD (SA ⊥ đáy)`).
2. `plugins/math_studio/ui/board/view_3d_board.js`
   - Set `text: { display: 'internal' }` on `initBoard` so all 3D vertex labels (`S, A, B, C, D, O, M, N, H, G`) are rendered as `<svg><text>` nodes in italic math serif (`Cambria Math`) and are 100% preserved when exported to the chalkboard.
   - Set `xAxis: { visible: false }, yAxis: { visible: false }, zAxis: { visible: false }` on `view3d` so the 3 stray coordinate sticks never clutter synthetic geometry figures.
   - Render models from `parseGeometryProblem`, including 3D right-angle markers (`∟`), base diagonals (`AC, BD` dashed when `O` is used), midpoints/projections, and clear solid vs. dashed edge visibility.
3. `plugins/math_studio/ui/export/board_exporter.js`
   - Implement **Dual-Theme Chalk Palette Mapping**:
     - Map `#0f172a`, `#1f2937`, `#0b2348`, `rgb(11, 35, 72)` (both 2D axes and 3D solid edges) $\to$ Chalk White `#F8FAFC`.
     - Map curve colors to high-contrast Chalk counterparts on dark chalkboard:
       - SGK Blue `#1d4ed8` $\to$ Chalk Sky `#38BDF8`
       - Crimson `#dc2626` / `#d32f2f` $\to$ Chalk Coral `#FB7185`
       - Emerald `#059669` $\to$ Chalk Mint `#34D399`
       - Amber `#d97706` $\to$ Chalk Gold `#FACC15`
     - Map dashed projections / 3D hidden edges (`#64748b`, `#94a3b8`) $\to$ `rgba(248, 250, 252, 0.68)`.
     - Inline explicit `font-family`, `font-size`, `font-weight`, and `font-style` XML attributes on every `<text>` element so `flutter_svg` renders crisp textbook typography on the chalkboard.

