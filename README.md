# Mộc · Teacher Station (Học Lực)

> **Trạm Giảng Dạy Số Đa Năng & Hệ Sinh Thái Plugin Vi Nhân (Microkernel Teaching Station)**  
> Được xây dựng bằng **Flutter (Dart)** cho Desktop/Web và **Java 17 (Spring Boot 3)** cho dịch vụ đồng hành & Kho tiện ích (Marketplace).

---

## 1. Tổng Quan Sản Phẩm (Product Overview)

**Mộc · Teacher Station** là nền tảng bàn làm việc số chuyên dụng cho giáo viên trong bối cảnh dạy học trực tuyến (Online) và kết hợp (Hybrid). Thay vì buộc giáo viên phải chuyển đổi rời rạc giữa phần mềm trình chiếu, bảng trắng, trình duyệt Google Meet, ngân hàng đề thi PDF và các phần mềm mô phỏng môn học (Máy tính Casio, Trợ giảng Tiếng Anh, ĐGNL...), **Mộc · Teacher Station** hợp nhất toàn bộ quy trình **Soạn giảng $\rightarrow$ Quản lý lớp học $\rightarrow$ Giảng dạy trực tiếp $\rightarrow$ Đánh giá năng lực** vào một không gian duy nhất có tỷ lệ khung hình chuẩn **16:9**.

### Triết lý thiết kế cốt lõi
- **Tập trung vào bài giảng (Teacher-First Ergonomics):** Giao diện ấm áp, rõ ràng (Warm Paper & Chalkboard), giảm tải nhận thức để giáo viên tự tin điều phối tiết học.
- **Kiến trúc Vi nhân (Pure Microkernel Host):** Nhân ứng dụng (`frontend/lib/`) hoàn toàn độc lập với từng bộ môn. Mọi công cụ đặc thù môn học (Toán, Lý, Hóa, Tiếng Anh, Casio fx-580VN X...) được đóng gói thành các gói tiện ích `.hlep` tải về theo nhu cầu (**On-Demand Cloud Marketplace**) và giải phóng 100% tài nguyên khi đóng.
- **Đồng hành liền mạch cùng Google Classroom & Google Meet:** Tự động đồng bộ danh sách học sinh, khởi tạo phòng học, điều khiển duyệt vào phòng (Auto-Admit), micro và phát luồng bảng giảng trực tiếp qua Camera ảo độ trễ thấp (`wgc_broadcaster`).

---

## 2. Yêu Cầu Chức Năng (Functional Requirements — FR)

### FR-01: Xác Thực, Hồ Sơ Giáo Viên & Quản Lý Lớp Học (`Auth & Classroom Workspace`)
| Mã | Tên chức năng | Mô tả chi tiết | Trạng thái |
| :--- | :--- | :--- | :---: |
| **FR-01.1** | Đăng nhập đa phương thức | Hỗ trợ đăng nhập bằng Email/Số điện thoại + Mật khẩu, xác thực OTP khi đăng ký, Google OAuth2 Desktop và chế độ Dùng thử 1 chạm (Demo). | ✅ Hoàn thành |
| **FR-01.2** | Đồng bộ Google Classroom | Kết nối tài khoản Google của giáo viên, tự động đồng bộ danh sách khóa học, học sinh (Roster) và tự động kiểm tra lại khóa học đang chờ kích hoạt (`PROVISIONED`) khi quay lại ứng dụng. | ✅ Hoàn thành |
| **FR-01.3** | Lịch học & Quản lý buổi học | Lên lịch buổi dạy, khởi tạo phòng học trực tuyến, lưu trữ lịch sử buổi dạy và xuất báo cáo/bài giảng sau tiết học. | ✅ Hoàn thành |

### FR-02: Không Gian Bảng Giảng Đa Trang & Soạn Bài (`Ergonomic 16:9 Studio & Lesson Planning`)
| Mã | Tên chức năng | Mô tả chi tiết | Trạng thái |
| :--- | :--- | :--- | :---: |
| **FR-02.1** | Sân khấu 16:9 & Bảng phấn đa trang | Không gian bảng viết chuẩn 16:9 hỗ trợ bút viết lực nhấn mượt (`perfect_freehand`), bút dạ quang, tẩy, hình học cơ bản, nhiều trang bảng và chế độ chia đôi màn hình (Split View). | ✅ Hoàn thành |
| **FR-02.2** | Ngăn kéo Tài liệu & PDF | Nhập tài liệu PDF/hình ảnh vào bài giảng, mở cửa sổ đọc tài liệu song song với bảng viết, khoanh vùng (Snip) và áp lớp Highlight trực tiếp lên file PDF. | ✅ Hoàn thành |
| **FR-02.3** | Soạn bài trước giờ lên lớp (Planning Mode) | Chế độ soạn giáo án độc lập kèm ghi chú diễn giả (Speaker Notes), cho phép nhân bản (1-Click Clone) toàn bộ trang bảng và tài liệu sang buổi dạy thực tế. | ✅ Hoàn thành |
| **FR-02.4** | Phụ kiện lớp học nổi (Floating Accessories) | Đồng hồ đếm ngược làm bài (Floating Timer), khung hình Camera giáo viên (Floating PIP) và thẻ ghim kiến thức (Smart Chalk Stickers) trên bảng. | ✅ Hoàn thành |

### FR-03: Tự Động Hóa Google Meet & Điều Phối Phòng Họp (`Meet Cockpit & Audio Bridge`)
| Mã | Tên chức năng | Mô tả chi tiết | Trạng thái |
| :--- | :--- | :--- | :---: |
| **FR-03.1** | Tự động mở & tham gia Google Meet | Tự động khởi chạy phòng họp Google Meet trong WebView2 ẩn/nhúng, tự động tắt micro/camera trình duyệt và bấm tham gia phòng họp. | ✅ Hoàn thành |
| **FR-03.2** | Duyệt học sinh & Quản lý người tham gia | Hiển thị dải học sinh (Student Strip) và bảng điều khiển Meet Cockpit: thông báo số người chờ duyệt, duyệt tự động (Auto-Admit), theo dõi trạng thái phát biểu/giơ tay và kết thúc cuộc họp cho tất cả. | ✅ Hoàn thành |
| **FR-03.3** | Đồng bộ Micro hệ thống & Phụ đề/Dịch thuật | Đồng bộ trạng thái Mute/Unmute và âm lượng trực tiếp với Windows Audio Endpoint, tích hợp cầu nối âm thanh phục vụ phụ đề/phiên dịch trực tiếp. | ✅ Hoàn thành |
| **FR-03.4** | Phát hình bảng giảng qua Camera ảo (WGC) | Chụp trực tiếp cửa sổ bảng giảng bằng C++ `Windows.Graphics.Capture` (`wgc_broadcaster`) và truyền tới DirectShow Virtual Camera (`UnityCapture`). | ✅ Hoàn thành |

### FR-04: Hệ Thống Đề Thi, Ngân Hàng Câu Hỏi & Phân Tích Năng Lực (`Exam Workspace`)
| Mã | Tên chức năng | Mô tả chi tiết | Trạng thái |
| :--- | :--- | :--- | :---: |
| **FR-04.1** | Bóc tách đề thi từ PDF | Tải lên file PDF đề thi, tự động chuẩn hóa văn bản (chống lỗi font ligatures tiếng Việt), trích xuất câu hỏi và quy trình duyệt nguồn câu hỏi. | ✅ Hoàn thành |
| **FR-04.2** | Ngân hàng câu hỏi & Ma trận đề | Quản lý câu hỏi theo chủ đề, kỹ năng, độ khó; xây dựng ma trận đề và sinh đề thi tự động; xuất đề thi ra PDF chuẩn in ấn. | ✅ Hoàn thành |
| **FR-04.3** | Chấm điểm & Phân tích học lực | Ghi nhận kết quả kiểm tra theo lớp/học sinh, thống kê phổ điểm, phân tích điểm mạnh/yếu theo từng kỹ năng và gợi ý lộ trình ôn tập. | ✅ Hoàn thành |

### FR-05: Hệ Sinh Thái Plugin & Kho Tiện Ích Đám Mây (`Plugin Marketplace & Schema v2.1 Host`)
| Mã | Tên chức năng | Mô tả chi tiết | Trạng thái |
| :--- | :--- | :--- | :---: |
| **FR-05.1** | Kho tiện ích đám mây (Cloud Marketplace) | Backend quét động các gói `.hlep`, cung cấp API danh mục (`GET /api/marketplace/plugins`), kiểm tra toàn vẹn `SHA-256` và tải gói (`GET /api/marketplace/plugins/{id}/download`). | ✅ Hoàn thành |
| **FR-05.2** | Cài đặt 1 chạm & Lưu đệm ngoại tuyến | Giáo viên xem danh mục tiện ích ngay trong Studio, tải về `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/`, tự động cập nhật khi có phiên bản mới và dùng được cả khi mất mạng. | ✅ Hoàn thành |
| **FR-05.3** | Chạy song song đa tiện ích (Multi-Instance) | Cho phép mở đồng thời tiện ích thiết bị nổi (`floating_window`) cùng lúc với tiện ích ngăn kéo gắn bài giảng (`bottom_drawer` / `drawer_panel`). | ✅ Hoàn thành |
| **FR-05.4** | Khay công cụ động (`contributes.tools`) | Tự động vẽ thanh công cụ bộ môn (`SubjectToolPalette`) dựa trên khai báo `contributes.tools` trong `manifest.json` (theo chuẩn VS Code Extension Contribution Points). | ✅ Hoàn thành |
| **FR-05.5** | Tự động tiêm SDK (`inject_sdk: true`) | Máy chủ nội bộ `PluginWebServer` tự động tiêm `hocluc-plugin-sdk.js` vào các dự án Web/WASM mã nguồn mở mà không cần sửa mã nguồn gốc. | ✅ Hoàn thành |
| **FR-05.6** | Chế độ Thiết bị vật lý sát viền (`frameless: true`) | Hiển thị **chỉ đúng thân thiết bị vật lý** trên bảng đen (ví dụ: **Máy tính Casio fx-580VN X** `336x624`), không có khung viền/header/footer thừa, tích hợp dải kéo thả trên viền máy và nút đóng `×` gọn nhẹ. | ✅ Hoàn thành |

---

## 3. Yêu Cầu Phi Chức Năng (Non-Functional Requirements — NFR)

| Mã | Thuộc tính chất lượng | Chỉ tiêu & Cơ chế đảm bảo kỹ thuật |
| :--- | :--- | :--- |
| **NFR-01** | **Tính cô lập kiến trúc (Microkernel Isolation & Zero-Hardcode)** | - **0 dòng code hardcode** tên/ID plugin (`english_assistant`, `casio_calculator`, `com.hocluc.plugin.*`) trong toàn bộ thư mục `frontend/lib/`.<br>- **0 lệnh import chéo** giữa `frontend/lib/` và `plugins/`.<br>- Được kiểm tra tự động bằng chốt chặn cứng `flutter test test/architecture_test.dart` trên GitHub Actions CI. |
| **NFR-02** | **Hiệu năng & Quản lý bộ nhớ (Performance & Lazy Disk Cache)** | - **Không nạp raw bytes của gói `.hlep` vào RAM (`filesMap` in-memory):** Mọi plugin được giải nén ra ổ đĩa cục bộ và phục vụ qua `PluginWebServer` (`http://127.0.0.1:<ephemeral_port>/`) theo nhu cầu.<br>- Nét vẽ bảng phấn đạt **60 FPS** trên màn hình Full HD / 2K nhờ cơ chế lưu đệm `Path` (`_cachedPath`) trong `BoardStroke`.<br>- Khi đóng plugin, 100% tiến trình con (Python/Binary Sidecar) bị thu hồi ngay lập tức qua `ProcessSupervisor`. |
| **NFR-03** | **Bảo mật & An toàn tiến trình (Security & Sandboxing)** | - **Chống tấn công Zip Slip:** `PluginStorageManager` kiểm tra nghiêm ngặt đường dẫn giải nén (`..`) trước khi ghi xuống đĩa.<br>- **Xác thực toàn vẹn gói tin:** Kiểm tra mã băm `SHA-256` khi tải gói `.hlep` từ Marketplace.<br>- **Cổng mạng động (Dynamic Ephemeral Ports):** Tuyệt đối không dùng cổng cố định (như `18888`); mọi dịch vụ nội bộ và Sidecar nhận cổng động từ OS.<br>- **Xác thực API cục bộ:** Giao tiếp giữa Frontend và Spring Boot Companion được bảo vệ bằng `SecurityTokenInterceptor` (`X-Companion-Token`). |
| **NFR-04** | **Khả năng hoạt động ngoại tuyến (Offline Resilience)** | - Danh mục Marketplace và các gói plugin đã cài đặt được lưu đệm trong `SharedPreferences` và `%LOCALAPPDATA%/HocLuc/plugins/`. Giáo viên vẫn mở được Máy tính Casio và các tiện ích đã tải ngay cả khi mất kết nối Internet hoặc Backend chưa bật. |
| **NFR-05** | **Khả năng mở rộng cho Lập trình viên (Developer Extensibility)** | - Thành viên mới hoặc bên thứ ba có thể tạo plugin môn học mới hoặc nhúng dự án Open-Source (HTML/JS/React/WASM) **trong dưới 5 phút** chỉ bằng 1 file `manifest.json` (Schema v2.1) và 1 lệnh đóng gói `node scripts/package_plugin.mjs <folder>` mà không cần chạm vào code Flutter hay Java. |
| **NFR-06** | **Tính tương thích đa độ phân giải & Đóng gói độc lập (Portability)** | - Giao diện vượt qua kiểm thử hình học tự động (`visual_restyle_test.dart`) trên 4 cấu hình màn hình: `1366×768`, `1440×900`, `1920×1080 (100%)` và `1920×1080 (125% DPI)`.<br>- Hỗ trợ đóng gói thành bản Windows Portable (`.exe`) tự chứa Java 17 JRE (`jlink`) và WebView2, chạy không cần quyền Admin. |

---

## 4. Kiến Trúc Hệ Thống & Cấu Trúc Dự Án (Repository Structure)

```text
HocLuc-TeacherStation-Flutter/
├── .github/workflows/             # Pipeline CI tự động (Backend CI & Frontend Architecture Gate)
├── .agents/rules/                 # Quy tắc bắt buộc cho AI Coding Agents (Schema v2.1)
├── backend/
│   ├── api/                       # Spring Boot 3 Companion & Plugin Marketplace Service (cổng 47831)
│   ├── db/                        # Lược đồ cơ sở dữ liệu (init.sql)
│   └── whiteboard-host/           # Nhân bảng viết Netless / Fastboard
├── frontend/                      # Ứng dụng Flutter (Windows Desktop & Web)
│   ├── lib/
│   │   ├── constants/             # Hệ thống màu sắc, khoảng cách, chuyển động (Design Tokens)
│   │   ├── models/                # StudioState, PluginManifest (Schema v2.1), dữ liệu bài giảng
│   │   ├── screens/               # Login, Dashboard, Lobby, Studio (16:9), ExamWorkspace
│   │   ├── services/              # PluginManager, PluginWebServer, PluginMarketplaceService, HostBridge
│   │   └── widgets/               # FloatingPluginWindow (Frameless/Standard), SubjectToolPalette, Stage
│   ├── plugins/
│   │   ├── audio_bridge/          # Plugin kết nối âm thanh hệ thống
│   │   └── wgc_broadcaster/       # Plugin C++ Windows.Graphics.Capture phát hình độ trễ thấp
│   └── test/                      # Hơn 270 bài kiểm thử Unit, Widget, E2E & Architecture Invariants
├── plugins/                       # Kho nguồn & gói tiện ích mở rộng độc lập (.hlep)
│   ├── casio_calculator/          # Plugin Máy tính Casio fx-580VN X (Frameless Bare-Device)
│   ├── casio_calculator.hlep      # Gói phân phối Casio tự động phục vụ qua Backend Marketplace
│   ├── english_assistant/         # Plugin Trợ giảng Tiếng Anh (S-V-O-A & ĐGNL + Python Sidecar)
│   └── english_assistant.hlep     # Gói phân phối Trợ giảng Tiếng Anh
├── scripts/
│   └── package_plugin.mjs         # Công cụ CLI kiểm tra Schema v2.1 & đóng gói .hlep kèm SHA-256
├── docs/architecture/             # Tài liệu kiến trúc & Cẩm nang phát triển Plugin cho thành viên mới
├── AGENTS.md                      # Hiến pháp kiến trúc bắt buộc cho Lập trình viên & AI Agent
└── Build-Windows.ps1              # Script đóng gói bản phân phối độc lập trên Windows (.exe)
```

---

## 5. Hướng Dẫn Cài Đặt & Khởi Chạy (Quick Start)

### Yêu cầu môi trường
- **JDK 17+** (có `java` và `jlink` trong `PATH`)
- **Apache Maven 3.9+**
- **Flutter SDK 3.27+** (Dart 3.5+)
- **Node.js 20+** (dùng cho script đóng gói plugin `scripts/package_plugin.mjs`)
- **Hệ điều hành:** Windows 10/11 x64 (bật **Developer Mode** trong *Settings > System > For developers*)

### Bước 1: Khởi chạy Backend Companion & Marketplace API (Terminal 1)
```powershell
cd backend/api
mvn spring-boot:run
```
*Dịch vụ khởi chạy tại `http://127.0.0.1:47831` (API Kho tiện ích: `http://127.0.0.1:47831/api/marketplace/plugins`).*

### Bước 2: Khởi chạy Ứng dụng Teacher Station (Terminal 2)
```powershell
cd frontend
flutter pub get

# Chạy ứng dụng gốc trên Windows Desktop (Khuyến nghị để dùng đầy đủ WebView2 & Plugin):
flutter run -d windows

# Hoặc chạy xem trước trên trình duyệt Chrome:
flutter run -d chrome
```

---

## 6. Phát Triển Tiện Ích Mở Rộng (Plugin Development — Schema v2.1)

Thành viên mới có thể tạo plugin môn học mới mà **không cần sửa bất kỳ dòng code nào trong `frontend/lib/`**:

1. Tạo thư mục `plugins/<ten_plugin>/` chứa giao diện `ui/index.html`, `icon.png` và `manifest.json` (xem 2 mẫu copy-paste trong [`docs/architecture/plugin-development-guide.md`](docs/architecture/plugin-development-guide.md)).
2. Đóng gói thành tệp `.hlep` bằng lệnh:
   ```powershell
   node scripts/package_plugin.mjs <ten_plugin>
   ```
3. Kiểm tra tính tuân thủ kiến trúc:
   ```powershell
   cd frontend
   flutter test test/architecture_test.dart
   ```

> 📖 Xem hướng dẫn chi tiết tại:
> - [`docs/architecture/plugin-development-guide.md`](docs/architecture/plugin-development-guide.md) — Cẩm nang phát triển Plugin & 2 mẫu `manifest.json` chuẩn Schema v2.1.
> - [`AGENTS.md`](AGENTS.md) — Các nguyên tắc bất biến (Hard Invariants) của hệ thống.

---

## 7. Kiểm Thử Chất Lượng & Cổng Chặn CI/CD (Quality Assurance)

Mọi Pull Request vào nhánh `develop` / `main` đều được kiểm tra tự động qua 2 luồng GitHub Actions:

### 1. Backend CI (`.github/workflows/ci-backend.yml`)
```powershell
cd backend/api
mvn -B clean test
```

### 2. Frontend CI & Chốt Chặn Kiến Trúc (`.github/workflows/ci-frontend.yml`)
```powershell
cd frontend

# 1. Phân tích tĩnh (0 lỗi / cảnh báo)
flutter analyze --no-fatal-infos

# 2. Chốt chặn Kiến trúc Plugin (5 bất biến cứng trong AGENTS.md)
flutter test test/architecture_test.dart

# 3. Toàn bộ Unit, Widget, Visual Geometry & Casio E2E Tests (>270 tests)
flutter test
```

---

## 8. Đóng Gói Bản Phân Phối Windows Độc Lập (`.exe`)

Để xuất bản gói cài đặt chạy ngay cho giáo viên (không cần cài Java, Flutter hay Node.js trên máy giáo viên):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Windows.ps1
```
Bản đóng gói hoàn chỉnh (kèm JRE 17 rút gọn và WebView2) sẽ được xuất ra tại `dist/HocLuc-Teacher-Windows-x64/`.
