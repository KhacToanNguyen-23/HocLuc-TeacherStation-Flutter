# Brainstorm: Hệ Thống Tiện Ích Môn Học (Subject Plugins Marketplace) Chuẩn Google Meet

**Date:** 2026-10-12
**Status:** Completed

---

## Ideas Explored

1. **Option A: Modal Dialog trung tâm (Workspace Marketplace):** Mở cửa sổ popup lớn giữa màn hình để duyệt danh sách plugin. (Dismissed: Gián đoạn tầm nhìn giảng dạy trên bảng của giáo viên).
2. **Option B: Phân nhóm tab kỳ thi THPT & ĐGNL riêng biệt:** Chia các tab cứng cho từng kỳ thi. (Dismissed: Người dùng muốn danh sách chung thống nhất, trực quan và không rườm rà).
3. **Option C: Right Activities Panel kiểu Google Meet + OOP Microkernel (Selected):**
   - Mở panel trượt từ bên phải (Right Side Panel) giống hệt bảng "Hoạt động" (Activities / Add-ons) của Google Meet.
   - Danh sách plugin thống nhất hiển thị các tiện ích (Desmos, Casio fx-580, Đồng hồ ĐGNL, Bảng tuần hoàn, Quick Quiz).
   - Mỗi item có icon đặc trưng, tên tiện ích ngắn gọn, trạng thái Cài đặt / Gỡ bỏ hoặc Mở trực tiếp.
   - Khi cài đặt, plugin tự động xuất hiện trên thanh công cụ Studio hoặc danh mục "Đã cài đặt" để bấm là mở ngay dạng Floating Widget hoặc Board Tool.

---

## User's Direction

- **Giao diện:** Panel trượt từ bên phải giống hệt bảng **Hoạt động (Activities)** của Google Meet.
- **Phân loại:** Để chung một danh sách trực quan, không chia thành các nhóm/tab phức tạp.
- **Phong cách tương tác:** Hướng 3 (Kết hợp cả Cửa sổ nổi `FloatingWidget` lẫn Công cụ gắn trên bảng `BoardTool`).
- **Thiết kế mã nguồn:** Hướng đối tượng (OOP) rõ ràng với lớp trừu tượng `SubjectPlugin` và bộ quản lý `PluginManager`.

---

## OOP Architecture Design

```
+-------------------------------------------------------------+
|                     <<abstract>>                            |
|                    SubjectPlugin                            |
+-------------------------------------------------------------+
| - id: String                                                |
| - name: String                                              |
| - icon: IconData                                            |
| - isInstalled: bool                                         |
| - isEnabled: bool                                           |
+-------------------------------------------------------------+
| + buildFloatingWidget(BuildContext): Widget?                |
| + buildBoardTool(BuildContext): Widget?                     |
| + onInstall(): Future<void>                                 |
| + onUninstall(): Future<void>                               |
+-------------------------------------------------------------+
                               ^
                               | extends
        +----------------------+----------------------+
        |                      |                      |
+---------------+      +---------------+      +---------------+
|  DesmosGraph  |      | CasioCalc580  |      |   DgnlTimer   |
|    Plugin     |      |    Plugin     |      |    Plugin     |
+---------------+      +---------------+      +---------------+
```

- **`PluginManager` (ChangeNotifier / Singleton):**
  - Quản lý danh sách các plugin có sẵn trong hệ sinh thái.
  - Lưu trạng thái cài đặt vào `SharedPreferences`.
  - Cung cấp luồng stream/listener để UI tự động cập nhật ngay khi giáo viên bấm "Cài đặt" hoặc "Gỡ bỏ".

---

## Open Questions

- Không có. Định hướng thiết kế đã thống nhất hoàn toàn.

---

## Risks & Mitigations

- **Rủi ro xung đột không gian hiển thị:** Nhiều cửa sổ nổi mở cùng lúc có thể che khuất bảng đen và PDF.
  - *Giải pháp:* Hỗ trợ nút thu nhỏ (Minimize), kéo thả vị trí (Draggable), và nhớ tọa độ cửa sổ.
