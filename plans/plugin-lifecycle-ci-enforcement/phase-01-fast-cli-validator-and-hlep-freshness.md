# Phase 01: Fast CLI Validator & Hash Freshness (`scripts/validate_plugins.mjs`)

**Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/plugin-lifecycle-ci-enforcement/plan.md)  
**Status:** Completed  
**Target File:** `scripts/validate_plugins.mjs`  

---

## 1. Mục Tiêu & Yêu Cầu

Xây dựng công cụ dòng lệnh `scripts/validate_plugins.mjs` hoạt động độc lập, không phụ thuộc thư viện ngoài (`node_modules`), chạy cực nhanh (< 150ms) trên cả Windows, macOS và Linux.

### Tiêu chí nghiệm thu:
1. **Schema v2.1 Verification:**
   - Kiểm tra mọi thư mục trong `plugins/` (trừ file ẩn và file `.hlep`) phải có `manifest.json`.
   - `id`: bắt buộc format `com.hocluc.plugin.<name>`.
   - `name`, `version`, `author`, `category` không được để trống.
   - `ui.placement` thuộc whitelist: `['floating_window', 'bottom_drawer', 'drawer_panel', 'right_panel']`.
   - `ui.entry` (hoặc `main`) phải trỏ tới file thực tế tồn tại trên đĩa (ví dụ `ui/index.html`).
   - `icon.png` phải tồn tại.
   - Nếu có `backend`: kiểm tra file `backend.entry` tồn tại.
2. **Hash & Freshness Drift Detection:**
   - Bắt buộc phải có file `plugins/<name>.hlep`.
   - Quét mtime (thời gian sửa đổi gần nhất) của tất cả file trong `plugins/<name>/` (bỏ qua `node_modules`, `__pycache__`, `.venv`).
   - Nếu có bất kỳ file nguồn nào có mtime mới hơn file `.hlep`, báo lỗi `OUT_OF_SYNC: Plugin <name> has been modified but .hlep archive was not updated!`.
3. **Cờ `--fix` tự động đóng gói:**
   - Khi chạy `node scripts/validate_plugins.mjs --fix`, tự động gọi `package_plugin.mjs` cho các plugin bị thiếu hoặc out-of-sync.
4. **Actionable Error Messages:**
   - Mỗi lỗi in ra hướng dẫn rõ ràng kèm câu lệnh sửa lỗi để cả người và AI Agent có thể khắc phục tức thì.

---

## 2. Các Bước Triển Khai

1. Tạo file `scripts/validate_plugins.mjs` với `import.meta.url` để xác định project root độc lập với CWD.
2. Viết hàm duyệt cây thư mục `plugins/` loại trừ `*.hlep`, `.*`.
3. Viết hàm `validateManifest(dir, manifest)`.
4. Viết hàm `checkFreshness(dir, hlepPath)`.
5. Bổ sung hỗ trợ `--fix` gọi lại logic đóng gói khi cần.
6. Test thử với trạng thái hiện tại của repo (`node scripts/validate_plugins.mjs`).

