# Phase 04 — Animation đơn giản có giọng đọc

Trạng thái: đề xuất. Story: P1 animation ưu tiên. Phụ thuộc: 03.

## Công việc

- Renderer xác định theo template: chữ xuất hiện, slide, sơ đồ, hình minh họa, đánh dấu vùng; dùng SVG/canvas/template giới hạn và timeline rõ ràng. Không thực thi JavaScript/Python tùy ý do LLM tạo.
- MVP dùng narration tiếng Anh: transcript Việt → dịch Việt–Anh → Kokoro tiếng Anh, theo lựa chọn người dùng. Có thể giữ giọng gốc Việt cắt theo nguồn; không yêu cầu TTS tổng hợp tiếng Việt để pass. Adapter tiếng Việt là mở rộng phải benchmark trước khi hứa hỗ trợ.
- Synth theo cảnh/câu, normalize audio, tính lại thời lượng từ âm thanh; phụ đề đồng bộ. Preview trong app, điều chỉnh phát âm/tốc độ và render lại cảnh bị ảnh hưởng.
- Worker render MP4, thumbnail và subtitle; FFmpeg dùng argument arrays, workspace riêng, timeout/quota và cleanup. Cache keyed bởi revision, model/voice/template và asset hash.
- App hiển thị tiến độ, hủy, lỗi thiếu model/renderer, xem lại video và phê duyệt artifact. Ghi chú/đáp án không lọt vào render projection.

## Nghiệm thu

- Bộ 3 bài gồm chữ, sơ đồ, hình: preview và MP4 phát được trên Windows/web và điện thoại học sinh; xác minh duration/audio/video không lệch dần, phụ đề bám lời.
- Thử narration tiếng Anh từ bản dịch Việt–Anh bằng model hiện có; báo riêng độ đúng ngữ nghĩa của bản dịch, thuật ngữ/phát âm và tính dễ nghe qua người chấm. Giọng gốc Việt là test riêng nếu bật; TTS Việt không nằm trong gate MVP.
- Hủy giữa render, file thiếu, audio quá dài, scene schema lỗi và thiếu dung lượng không tạo artifact được đánh dấu ready.
- Đo RAM/VRAM, thời gian render video 5/15 phút trên máy mục tiêu; công bố giới hạn thực tế thay vì cam kết thời gian chưa đo.
- Xuất video sentinel kiểm privacy; mỗi artifact ghi revision và nguồn, chỉ artifact đã duyệt sang phase 05.

## Đầu ra

Video animation đơn giản và phụ đề có version. Cảnh/nhân vật sinh AI không là điều kiện pass phase này.
