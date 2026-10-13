# Báo cáo pilot AI speech — 13/10/2026

Branch `feat/local-ai-speech-translation`, base đề thi `36901c8`. Phạm vi pilot gồm code inference, native audio, điều khiển và đóng gói; installer tự tải model là bước tiếp theo. Máy đo: Windows x64, GTX 1650 4 GB VRAM, driver 580.88, khoảng 7.4 GiB RAM. Số đo dưới đây là kết quả trên máy này, không dùng làm cam kết cho máy khác.

## Phạm vi đã kiểm chứng

- UI giữ dropdown + toggle riêng. Config English/legacy enabled không kích hoạt phiên mới; chọn English không gửi request model. OFF/chuyển Tiếng Việt/mute hủy kết quả warm-up đến muộn. Test responsive từ panel nhỏ tới desktop.
- Toàn bộ 122 test Flutter passed; analyze các file thay đổi không có lỗi. Test mới xác nhận bridge khởi động ở trạng thái mute ngay từ lệnh start khi giáo viên đã tắt mic.
- Python runtime: VAD khoảng nghỉ, segment/frame hữu hạn, silence, PCM lỗi, auth, Origin, thứ tự transcript/audio và giới hạn WAV. 12 test passed.
- Backend: toàn bộ 53 test passed, gồm kiểm tra endpoint audio không hoạt động thiếu companion token, status không gọi connect và foreign Origin bị từ chối. Dữ liệu H2 vẫn ở `backend/api/data`, không đổi sang database tại root.
- Flutter Windows Release đã build với plugin WASAPI. Native integration test liệt kê được 3 input/2 output thật, phát 100 ms PCM im lặng ra Speakers Realtek và nhận `previewEnded` về Flutter. Đã kiểm tra render/event thật; không mở micro và chưa chứng minh chất lượng nghe/capture/mute ở thiết bị.
- HTTP qua Java thật nhận WAV, trả transcript Việt + bản dịch Anh + PCM 24 kHz. WebSocket thật nhận PCM theo frame và trả transcript rồi audio. Worker lazy trước test, được giải phóng sau `/audio/stop`.
- Gói `dist/HocLuc-AI-Native-Windows-20261013-224356` đã chạy lại HTTP/WebSocket với JRE jlink + Python 3.12.10 embedded và thư viện được copy trong gói. ASR CUDA INT8/float32, MT CPU INT8, TTS CUDA; mẫu stream trả PCM sau chốt đoạn 1438 ms. Java parent watcher đã nhả cổng test sau khi shell kết thúc. Đây là relocation trên máy hiện tại, chưa phải Windows sạch.

## Số đo và lựa chọn runtime

Các checkpoint gốc đã nạp/chạy; export PhoWhisper/VinAI INT8 được tạo riêng và giữ nguyên model gốc. VinAI dùng tokenizer/lang ID của checkpoint. Model manifest có SHA256 weights và export; revision tải gốc không có metadata nên không được suy đoán.

| Thử nghiệm | Kết quả đo |
|---|---|
| VinAI + Kokoro warm, ASR CPU INT8 | Dịch khoảng 793–802 ms, TTS 304–323 ms với câu văn gravity cố định; chưa gồm ASR |
| Java/WebSocket với ASR CPU INT8 | ASR 6364 ms, MT 1322 ms, TTS 711 ms; chốt đoạn → PCM server 8391 ms, vượt mục tiêu 3 s |
| ASR GPU `int8_float16` | Nhanh nhưng trả câu khác hẳn bản CPU trên cùng WAV; loại khỏi cấu hình pilot |
| ASR GPU `int8_float32`, benchmark riêng | Khoảng 736–876 ms; bản 5.5 s giống transcript CPU; bản 14.94 s vẫn có khác biệt/lỗi từ ngữ |
| Java/WebSocket, ASR GPU INT8/float32 + MT CPU INT8 + Kokoro CUDA | ASR 767 ms, MT 429 ms, TTS 249 ms; chốt đoạn → PCM server 1454 ms với một đoạn thử |
| HTTP WAV 14.94 s, cấu hình GPU trên | Tổng lần nạp lạnh + xử lý 52.2 s; riêng ASR 1794 ms, MT 1302 ms, TTS 3814 ms; audio Anh 7.075 s |

Báo cáo thực ở `.run/ai-java-integration/report.json` và `.run/ai-java-integration-gpu-idlefixed/report.json`; WAV đầu ra nằm cùng thư mục. So sánh ASR ở `.run/audio-asr-device-comparison.json`. Script opt-in có thể tạo lại với WAV được chỉ định trong hướng dẫn setup.

Input smoke là một WAV tiếng Việt từ archive công khai [FLEURS](https://storage.googleapis.com/xtreme_translations/FLEURS/vi_vn.tar.gz), member `home/vaxelrod/FLEURS/oss2_obfuscated/vi_vn/audio/dev/10056093347220194289.wav`. Chỉ trích một file; không có reference transcript đi kèm trong lần smoke này. Vì vậy không có WER/BLEU/COMET hoặc kết luận đạt chất lượng. Transcript có “vôi”, “hũ cao cổ” và dịch thành “lime” ở một lần chạy: lỗi ASR có thể đi qua model dịch rồi được đọc thành tiếng. Cần bộ câu lời giảng có đáp án để đánh giá số, công thức, đơn vị, tên riêng và thuật ngữ.

1454 ms là thời gian ở server sau chốt đoạn, chưa gồm native render, mạng Meet và thiết bị học sinh. Một mẫu không phải P50/P95. Khi vừa build/test và copy runtime lớn trên máy ít RAM, một lần nạp + xử lý WAV tăng lên 135 s; phải đo lại tải Flutter + Java + browser + inference trên cấu hình sử dụng thật. CPU fallback hoạt động về chức năng nhưng chưa đạt yêu cầu độ trễ.

## Các bước acceptance còn thiếu

| Bước | Trạng thái |
|---|---|
| Dropdown/toggle, config migration, auth, hủy phiên | Đã qua test phần mềm |
| Model thật, pipeline WAV/WebSocket, worker cleanup | Đã qua smoke local |
| Micro vật lý → native bridge → output; mute đo ở endpoint | Chưa thử âm thanh thiết bị thực |
| Driver VB-CABLE | Bộ cài đã chuẩn bị và ký hợp lệ; chưa cài, inventory chưa có endpoint |
| Người học khác nghe qua Meet | Chưa thử |
| 20–30 phút vừa giảng/vẽ bảng, không queue tích lũy/đọc trùng | Chưa thử |
| P50/P95 từ lời nói/chốt đoạn tới người học | Chưa đo |
| Chất lượng tập câu giáo viên có transcript chuẩn | Chưa đạt acceptance |
| Windows sạch/macOS/Flutter web | Chưa kiểm chứng / platform ngoài pilot |

Không gọi pipeline này là sẵn sàng cho lớp thật trước khi hoàn thành các bước nghe/đo trên. OFF luôn giữ nguyên khả năng quay về giọng gốc trên thiết bị còn hoạt động. Denoise không được báo sẵn sàng; bộ ba không tự cung cấp tính năng đó.

## Thứ tự kiểm tra tại lớp

1. Cài virtual audio, chọn đúng cặp endpoint như `docs/ai-speech-setup.md`; dùng tai nghe và participant trên máy khác.
2. Giọng gốc 30 s → English dropdown OFF vẫn giọng gốc → ON chuẩn bị/Anh → OFF giữa một câu trở về giọng gốc.
3. Mute trong lúc nạp model, inference và phát TTS; unmute không đọc lại audio cũ. Rút mic/đổi output; nhãn phải phản ánh mất thiết bị.
4. Đọc tập câu 2–6 s có transcript/thuật ngữ/số chuẩn, thử 20–30 phút cùng vẽ bảng. Ghi thời điểm phát và ghi âm ở participant, tải RAM/VRAM, lỗi và số đoạn; tính P50/P95 rồi quyết định gate.
5. Rời lớp/đóng app và forced exit; kiểm tra endpoint đã nhả, child process không còn. Nếu không đạt, để toggle OFF và sửa lỗi/đổi cấu hình trước rollout.
