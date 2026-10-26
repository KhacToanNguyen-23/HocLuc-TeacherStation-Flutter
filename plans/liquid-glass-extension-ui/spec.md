# Spec: Tái Thiết Kế Toàn Bộ Giao Diện Extension Theo Phong Cách Liquid Glass (VisionOS)

**Slug:** `liquid-glass-extension-ui`  
**Date:** 2026-10-20  
**Brainstorm Report:** `plans/reports/261020-liquid-glass-extension-ui-brainstorm.md`  

---

## 1. Bối Cảnh & Vấn Đề (Problem Statement)

Khi giảng dạy trực tiếp trên bảng thông minh hoặc slide PDF bằng TeacherStation:
1. **Thanh công cụ môn học nổi (`SubjectToolPalette`)** hiện tại có nền màu xanh đen đặc phẳng (`#1E293B`), các nút con có viền thô và nền đục, che khuất một phần dòng viết hoặc hình ảnh bài giảng ngay dưới thanh công cụ.
2. **Cửa sổ kết quả của Extension** (Webview drawer của Trợ giảng Tiếng Anh) sử dụng nền tối rêu dày (`#111a16`, `#182620`), tạo cảm giác như một bức tường đặc đè lên bài học thay vì một tấm kính thông minh nổi trên không gian bảng vẽ.
3. Giáo viên cần một hệ thống giao diện **Liquid Crystal / VisionOS Glass** trong suốt, có chiều sâu quang học khúc xạ (refraction) và viền sáng phản chiếu (*Specular Rim Lighting*), cho phép nhìn thấu trang bài giảng bên dưới; đồng thời có nút bấm nhanh chuyển đổi 3 mức độ kính (`Clear` -> `Frosted` -> `Solid`) đồng bộ để đảm bảo chữ luôn đọc rõ dù bảng viết nhiều hay ít nét phấn.

---

## 2. User Stories & Phân Loại Ưu Tiên (P1 / P2 / P3)

### P1 — Bắt buộc (Core MVP)

1. **[P1 - Giáo viên] Thanh công cụ dock nổi kính lỏng trên bảng vẽ (`LiquidGlassDock`):**
   - **Là một** giáo viên đang viết bài hoặc phân tích tài liệu trên bảng phấn,
   - **Tôi muốn** thanh công cụ môn học (`SubjectToolPalette`) có hiệu ứng kính khúc xạ mờ trong suốt (BackdropFilter blur, viền sáng specular phản chiếu ánh sáng tự nhiên),
   - **Để** nhìn xuyên thấu nét phấn và slide PDF bên dưới thanh công cụ mà không bị che khuất tầm nhìn.

2. **[P1 - Giáo viên] Chuyển đổi 3 mức độ kính đồng bộ chỉ bằng 1 nút bấm (`[ 👁 ]`):**
   - **Là một** giáo viên đang giảng bài trong các tình huống nội dung bảng vẽ khác nhau,
   - **Tôi muốn** có nút biểu tượng thấu kính `[ 👁 ]` trên thanh công cụ để bấm xoay vòng nhanh qua 3 mức độ:
     - 💎 **Clear Glass** (Độ đục ~15%, nhìn thấy rõ toàn bộ bài giảng bên dưới)
     - ❄️ **Frosted Glass** (Độ đục ~50%, mờ sương cân bằng giữa nhìn bài giảng và đọc chữ)
     - 🛡️ **Solid Crystal** (Độ đục ~85%, kính đặc chống rối mắt khi bảng viết quá nhiều chữ)
   - **Để** thanh dock nổi và toàn bộ cửa sổ panel kết quả tự động chuyển độ mờ đồng bộ ngay tức thì.

3. **[P1 - Giáo viên] Giao diện kết quả phân tích cú pháp S-V-O dạng viên đá kính nổi:**
   - **Là một** giáo viên đang phân tích câu tiếng Anh cho học sinh,
   - **Tôi muốn** cửa sổ kết quả Webview có nền kính trong suốt và các token cú pháp (Chủ ngữ S, Động từ V, Tân ngữ O) hiển thị dạng viên nang kính (*Glass Gem Capsules*) phát quang viền quang học (Xanh dương cho S, Hồng cho V, Cam hổ phách cho O),
   - **Để** học sinh dễ dàng phân biệt cấu trúc ngữ pháp một cách trực quan, cuốn hút và cao cấp.

4. **[P1 - Kiến trúc & Developer] Modular Glass UI Kit dùng chung (Zero Hardcoded Names):**
   - **Là một** kỹ sư phát triển hệ thống plugin Microkernel,
   - **Tôi muốn** hệ thống CSS Liquid Glass và widget Flutter Glass được module hóa và tái sử dụng cho mọi plugin môn học khác qua Host Bridge mà không hardcode ID của bất kỳ plugin nào trong `frontend/lib/`,
   - **Để** bảo toàn tuyệt đối 7 bất biến kiến trúc trong `AGENTS.md`.

### P2 — Trải nghiệm mượt mà & Nâng cấp (Enhancement)

5. **[P2 - Giáo viên] Phản hồi xúc giác & Vệt sáng phản chiếu khi di chuột (Specular Sheen):**
   - **Là một** người dùng tương tác bằng chuột hoặc bút cảm ứng,
   - **Tôi muốn** khi hover vào các nút pill và thẻ từ vựng, một vệt sáng phản chiếu nhẹ lướt qua bề mặt kính và nút hơi nổi lên (`translateY(-1px)`),
   - **Để** cảm nhận độ chân thực của vật liệu kính thông minh.

6. **[P2 - Giáo viên] Nút công cụ đang hoạt động có hào quang lỏng (Liquid Glow Aura):**
   - **Là một** giáo viên đang bật chế độ phân tích cú pháp,
   - **Tôi muốn** nút `✦ Công cụ S-V-O` phát ra hào quang ánh sáng xanh lơ lan tỏa nhẹ trên viền kính,
   - **Để** biết rõ ràng công cụ nào đang sẵn sàng nhận diện trên bảng phấn.

---

## 3. Tiêu Chí Nghiệm Thu Định Lượng (Measurable Success Criteria)

- **SC-01 (Hiệu năng khung hình 60 FPS):** Thanh dock nổi `SubjectToolPalette` khi được kéo rê (drag & pan) trên bảng vẽ phấn và slide PDF duy trì tốc độ hiển thị mượt mà $\ge 55$ FPS trên Windows WebView2.
- **SC-02 (Chu kỳ chuyển đổi 3 mức độ kính):** Nhấp nút `[ 👁 ]` chuyển đổi tuần hoàn chính xác qua 3 trạng thái `clear` $\rightarrow$ `frosted` $\rightarrow$ `solid` $\rightarrow$ `clear`; độ đục nền thay đổi tương ứng:
  - `clear`: Opacity nền $0.15 \pm 0.05$, BackdropFilter blur $\sigma = 10$.
  - `frosted`: Opacity nền $0.50 \pm 0.05$, BackdropFilter blur $\sigma = 20$.
  - `solid`: Opacity nền $0.85 \pm 0.05$, BackdropFilter blur $\sigma = 28$.
- **SC-03 (Đồng bộ Host-Webview tức thì):** Khi đổi mức kính trên thanh dock nổi Flutter, sự kiện `GLASS_PRESET_CHANGE` được gửi qua `HostBridge` và Webview cập nhật CSS Custom Properties trong vòng $< 50\text{ms}$.
- **SC-04 (Độ tương phản khả đọc WCAG AA):** Ở mọi mức độ kính (kể cả `clear`), văn bản hiển thị (chữ tiếng Anh, nhãn nút bấm, thẻ ngữ pháp) đạt tỷ lệ tương phản (Contrast Ratio) $\ge 4.5:1$ so với nền bài giảng bên dưới nhờ bóng đổ quang học (*ambient drop shadow*) và viền chữ vi mô.
- **SC-05 (Kiến trúc sạch 100% PASS):** Lệnh kiểm thử cổng kiến trúc `flutter test test/architecture_test.dart` đạt **7/7 PASS**, không chứa chuỗi hardcode ID plugin trong `frontend/lib/`.
- **SC-06 (Tính nguyên vẹn của gói Plugin):** Chạy `node scripts/package_plugin.mjs english_assistant` tạo file `.hlep` hợp lệ, script `node scripts/validate_plugins.mjs` báo 0 lỗi.

---

## 4. Thiết Kế Kiến Trúc Kỹ Thuật (Technical Design Summary)

### A. Phía Flutter Host (`frontend/lib/`)
1. **`LiquidGlassContainer` (`frontend/lib/core/widgets/liquid_glass_container.dart`):**
   - Bọc trong `ClipRRect` với `BackdropFilter(filter: ImageFilter.blur(sigmaX, sigmaY))`.
   - Lớp nền: `LinearGradient` với góc chiếu $135^\circ$ mô phỏng ánh sáng phản xạ từ góc trên bên trái (`rgba(255,255,255, alpha1)` đến `rgba(255,255,255, alpha2)`).
   - Viền: Lớp viền khúc xạ kép với viền sáng trên `rgba(255,255,255, 0.45)` và viền tối dưới `rgba(255,255,255, 0.12)`.
   - Bóng đổ: 2 tầng bóng (*diffused ambient shadow* mềm mại phía dưới và *specular rim glow*).
2. **`SubjectToolPalette` (`frontend/lib/features/studio_board/presentation/subject_tool_palette.dart`):**
   - Ứng dụng `LiquidGlassContainer`.
   - Bổ sung nút `_GlassPresetButton` có icon thay đổi theo trạng thái (💎 Clear $\rightarrow$ ❄️ Frosted $\rightarrow$ 🛡️ Solid).
   - Khi bấm, cập nhật trạng thái `studio.glassPreset` và phát lệnh `HostBridge.notifyGlassPreset(preset)`.
3. **`FlatHostNative` (`frontend/lib/features/plugin_engine/presentation/flat_host_native.dart`):**
   - Thiết lập màu nền trong suốt cho controller WebView2 Windows (`setBackgroundColor(const Color(0x00000000))`) để nền bảng vẽ xuyên thấu qua cửa sổ mở rộng.

### B. Phía Plugin Webview (`plugins/english_assistant/ui/` & Shared Kit)
1. **Hệ thống Design Token `liquid-glass.css`:**
   ```css
   :root {
     --glass-blur: 20px;
     --glass-bg-opacity: 0.15;
     --glass-bg: rgba(255, 255, 255, var(--glass-bg-opacity));
     --glass-border: rgba(255, 255, 255, 0.35);
     --glass-specular: rgba(255, 255, 255, 0.7);
     --glass-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
     --glass-radius-pill: 9999px;
     --glass-radius-card: 18px;
   }
   ```
2. **Các Component Kính chuẩn hóa:**
   - `.liquid-pill-btn`: Nút bấm hình viên thuốc, viền phản xạ ánh sáng, hiệu ứng lún nhẹ khi bấm.
   - `.liquid-card`: Khung kết quả bo góc lớn $18\text{px}$, nền kính mờ, viền specular highlight góc $135^\circ$.
   - `.liquid-gem-token`: Viên nang từ vựng S-V-O với lõi màu gradient phát sáng (Cyan, Ruby, Amber) ẩn dưới lớp kính khúc xạ.
3. **Lắng nghe sự kiện đồng bộ từ SDK:**
   - Trong `app.js` / `sdk.js`: Lắng nghe message `GLASS_PRESET_CHANGE` từ Flutter Host để cập nhật class `.glass-clear`, `.glass-frosted`, `.glass-solid` lên thẻ `<body>`.

