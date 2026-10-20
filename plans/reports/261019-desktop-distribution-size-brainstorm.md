# Brainstorm Report: Đánh Giá Tính Thực Tế Về Dung Lượng Tải Về & Cài Đặt Cho Người Dùng Cuối (Giáo Viên)

- **Date:** 2026-10-19
- **Author:** AI Engineering & Architecture Team
- **Target Audience:** Giáo viên (End-users) tải ứng dụng `HocLuc-TeacherStation` trên Windows Desktop
- **Context:** Trả lời trực diện câu hỏi của Product Owner: *"project hiện tại tính thực tế khi download về có nặng không đối với người dùng cuối?"*

---

## 1. Tóm tắt kết luận (Executive Summary)

> **Trả lời trực diện:**  
> - **Nếu cấu hình chuẩn Thin Client / Microkernel (chỉ Flutter Host + Plugins On-Demand):** **RẤT NHẸ (~35 MB - 45 MB tải về)**.
> - **Nếu đóng gói cục bộ kiểu "All-in-One Monolith" (kèm Java JRE, Spring Boot JAR, và AI Speech Engine):** **RẤT NẶNG (> 1.5 GB - 3 GB tải về)** và sẽ làm treo hầu hết máy tính phổ thông của giáo viên trong thực chiến.

---

## 2. Bóc tách dung lượng thực tế từng tầng công nghệ (Component Breakdown)

| Tầng thành phần | Công nghệ | Dung lượng nén (Download Payload) | Dung lượng giải nén (Installed on Disk) | Đánh giá tính thực chiến cho Giáo viên |
|---|---|---|---|---|
| **1. Core Desktop App** | Flutter Windows Release x64 (`teaching_companion.exe`, `flutter_windows.dll`, `pdfium.dll`, WebView2 Host) | **~30 - 45 MB** | **~75 - 110 MB** | **Rất nhẹ**. Tải về trong 5-10 giây qua Wi-Fi trường học. Khởi động tức thì (dưới 1.5 giây). |
| **2. Plugin Extensions** | Micro-frontend (`.hlep` Packages) | **~18 MB** (Casio 700KB, English 16.8MB) | **~25 MB** (Lưu tại `%LOCALAPPDATA%\HocLuc\plugins`) | **Tối ưu tuyệt đối**. Tải On-Demand qua Plugin Marketplace khi giáo viên bấm "Cài đặt". Không tốn RAM tĩnh. |
| **3. Local Companion Service** | Spring Boot 3 (`companion-service-0.1.0.jar` + Custom JRE qua `jlink`) | **~90 - 130 MB** | **~180 - 250 MB** | **Trung bình - Nặng**. Vì Windows giáo viên không có Java, bắt buộc phải bundle 1 custom JRE (~70MB). |
| **4. AI Speech Translation Runtime** | Python 3.12 embedded + PyTorch 2.8 + Transformers + faster-whisper + Kokoro TTS | **~600 MB - 1.2 GB** | **~2.0 GB - 3.5 GB** | **Cực nặng**. Thư viện `torch` và `site-packages` quá đồ sộ đối với 1 desktop app giáo dục thông thường. |
| **5. AI Model Checkpoints** | PhoWhisper-small + VinAI Vi-En v2 + Kokoro-82M | **~1.0 GB - 2.0 GB** | **~2.5 GB** | **Khổng lồ**. Cần tải checkpoint safetensors/bin. Tải qua mạng trường học thường xuyên timeout/rớt mạng. |

---

## 3. Ba kịch bản phân phối (Packaging & Delivery Models)

### Kịch bản 1: "All-in-One Monolith" (Đóng gói tất cả vào 1 file Setup.exe)
- **Kích thước tải về:** **~1.8 GB - 3.2 GB**
- **Dung lượng sau khi cài:** **~4.5 GB - 6 GB**
- **Cơ chế:** Nhúng sẵn Flutter + JRE + Spring Boot JAR + Python Embedded + PyTorch + AI Weights + Driver Virtual Audio.
- **Thực tế người dùng:**
  - Giáo viên chờ tải 30 - 60 phút ở trường học (mạng trường thường bị bóp băng thông).
  - Khi mở ứng dụng: Máy tính giáo viên (phần lớn là Core i3/i5, RAM 8GB, không GPU rời) sẽ bị ngốn 100% RAM & CPU, gây giật lag hoặc treo máy khi Google Meet và AI inference chạy cùng lúc.
  - Mỗi lần có bản vá lỗi (bug fix) phải tải lại cả file 2 GB.
- **Kết luận:** **Không khả thi cho đại trà học đường.**

---

### Kịch bản 2: "Cloud Companion + Thin Client" (Mô hình SaaS Tiêu Chuẩn Doanh Nghiệp)
- **Kích thước tải về:** **~35 MB - 45 MB** (File InnoSetup `.exe` duy nhất).
- **Dung lượng sau khi cài:** **~90 MB** trên ổ C.
- **Cơ chế:**
  - File cài đặt máy giáo viên chỉ gồm Flutter Desktop Native và Host Engine.
  - Spring Boot API và các tác vụ nặng (AI Speech translation, chấm thi HSA/V-ACT, OCR) chạy trên Cloud Server hoặc Local Edge Server của nhà trường (giáo viên kết nối qua Wi-Fi nội bộ hoặc Internet).
  - Casio và English Assistant tải on-demand từ Marketplace (Casio 700KB tải trong 1 giây).
- **Thực tế người dùng:**
  - Tải về trong 5 giây, nhấn "Next" cài xong trong 10 giây.
  - Ứng dụng chạy siêu mượt trên mọi máy tính, kể cả máy tính cũ 10 năm trước.
  - Bản update Flutter tự động qua In-App Updater chỉ ~5 MB - 10 MB diff.
- **Kết luận:** **Mô hình khuyến nghị tối ưu số 1 cho người dùng cuối.**

---

### Kịch bản 3: "Modular Hybrid" (Chạy Core mượt, Cài Extension khi cần)
- **Kích thước tải về (Base):** **~45 MB** (Chỉ bảng vẽ Smart Board, Google Meet Cockpit, Marketplace).
- **Dung lượng khi mở rộng:**
  - Nếu giáo viên cần chấm thi hoặc trợ giảng: Tải Local Service Companion (~60 MB nếu compile GraalVM Native Binary không cần JRE).
  - Nếu giáo viên có laptop gaming/workstation và muốn chạy AI dịch tiếng Anh offline: Bấm nút "Tải AI Package" (~1.2 GB nền, có thanh tiến trình % và resume khi đứt mạng).
- **Kết luận:** **Phù hợp nhất nếu muốn giữ tính năng AI offline mà không ép 100% giáo viên phải gánh cục tạ vài Gigabytes.**

---

## 4. Bảng so sánh trực quan cho Product Owner

| Tiêu chí so sánh | Kịch bản 1: All-in-One Local | Kịch bản 2: Thin Client + Cloud | Kịch bản 3: Modular Hybrid |
|---|---|---|---|
| **Dung lượng tải lần đầu** | ⚠️ **1.8 GB - 3.2 GB (Quá nặng)** | 🟢 **35 MB - 45 MB (Cực nhẹ)** | 🟢 **45 MB (Base rất nhẹ)** |
| **Thời gian tải (Mạng trường ~20Mbps)** | 20 - 45 phút | **15 - 30 giây** | **20 giây** |
| **Cấu hình máy tối thiểu** | Core i7, 16GB RAM, GPU rời 4GB | **Core i3, 4GB RAM, Không cần GPU** | Core i3 (Base) / Core i5 (AI) |
| **Độ mượt khi giảng dạy** | Có nguy cơ đơ máy / nghẽn quạt tản nhiệt | Cực kỳ mượt, CPU < 5% | Mượt, module hóa an toàn |
| **Chi phí cập nhật (Update)** | Tải lại GBs | Tải diff vài MBs | Tải diff từng plugin độc lập |

