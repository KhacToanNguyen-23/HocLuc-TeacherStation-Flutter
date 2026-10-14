# Dịch lời giảng Việt → Anh trên Windows native

Triển khai ngày 13/10/2026 trên `feat/local-ai-speech-translation`. Giữ dropdown ngôn ngữ và toggle **Phát bản dịch tiếng Anh** riêng. Chọn English chưa chạy AI. Phiên mới luôn OFF; chỉ lưu ngôn ngữ, thiết bị và giọng đọc.

## Chạy trên checkout này

```powershell
Set-Location D:\Projects\HocLuc-Teacher
.\Start.ps1 -Mode Service -SkipBuild
& .\frontend\build\windows\x64\runner\Release\teaching_companion.exe
```

Trong lớp, mở panel cài đặt âm thanh. Chọn micro vật lý của giáo viên và đầu ra audio. Bấm **Phát giọng gốc** để bắt đầu bridge; khi chọn English và bật toggle, app tự khởi động bridge nếu cần. Trong thời gian nạp model, giọng gốc tiếp tục phát. Khi nhận ready, đường phát chuyển sang bản dịch Anh. OFF/chọn Tiếng Việt trả giọng gốc; mute xóa audio đang đợi và áp dụng cả hai đường. Không thu hoặc dịch lời nói trong thời gian mute.

Nếu model/runtime lỗi hoặc queue quá tải, app tắt yêu cầu dịch, xóa audio cũ và quay về giọng gốc khi thiết bị còn hoạt động. Mất thiết bị được báo chưa sẵn sàng. Giáo viên chủ động bật lại sau lỗi. Không có denoise hoặc voice cloning trong bộ ba này.

## Nghe thử trước khi nối vào Meet

Khi audio trực tiếp đã dừng và mic không mute, bấm **Nghe thử WAV**. Chọn WAV tiếng Việt mono/stereo 8–48 kHz, tối đa 15 giây/4 MB, rồi chọn loa hoặc tai nghe tại máy. App chạy cùng ba model và phát bản dịch tại đầu ra nghe thử; toggle lớp vẫn OFF. **Dừng audio** hủy phần đang xử lý/phát. Nên dùng tai nghe để tránh mic thu lại loa.

## Model/runtime

| Model gốc ngoài repo | Vai trò |
|---|---|
| `D:\AI-Training\models\PhoWhisper-small` | Giọng Việt → transcript Việt |
| `D:\AI-Training\models\vinai-translate-vi2en-v2` | Transcript Việt → văn bản Anh |
| `D:\AI-Training\models\Kokoro-82M` | Văn bản Anh → PCM mono 24 kHz |

Runtime độc lập ở `backend/ai-runtime/.venv`; không dùng environment Unsloth. Có pin trực tiếp và dependency đã resolve. Cài ở máy có Python 3.12:

```powershell
.\scripts\Setup-AiRuntime.ps1 -PythonPath 'C:\Users\LENOVO\AppData\Local\Programs\Python\Python312\python.exe' -TorchDevice cuda
.\scripts\Export-AiInt8.ps1
.\scripts\Export-AiManifest.ps1
```

Máy chỉ có CPU dùng `-TorchDevice cpu`, rồi đo lại hiệu năng. Script export từ đúng checkpoint hiện có sang hai thư mục mới `PhoWhisper-small-ct2-int8`, `vinai-translate-vi2en-v2-ct2-int8`; từ chối ghi đè export đã tồn tại. Checkpoint gốc được giữ nguyên.

Copy `backend/ai-runtime/config/models.example.json` thành `models.local.json` để đổi cấu hình; file local không vào Git. `HOC_LUC_AI_MODELS` đổi thư mục model, `HOC_LUC_AI_CONFIG` chọn JSON khác. `device` dùng cho baseline Transformers; `asr_device`/`tts_device` điều khiển đường đã export. Cấu hình mặc định tự chọn CUDA khi có, CPU khi không có. VinAI CT2 chạy CPU INT8. PhoWhisper GPU dùng `int8_float32`: FP16 trên GTX 1650 pilot đã tạo transcript không tương đương bản CPU nên không được chọn.

Python chỉ nghe loopback với token tạm do Java tạo. Java status không nạp model. WebSocket chỉ nạp model sau thao tác bật; WAV preview cũng là thao tác chủ động. Frame PCM 16 kHz được chốt theo khoảng nghỉ, đoạn tối đa 6 giây. Queue inference tối đa 3 đoạn; audio TTS chờ phát tối đa 8 giây. Quá hạn/đầy queue trả lỗi về giọng gốc. Không ghi nội dung lớp vào log mặc định. Script benchmark tùy chọn có ghi transcript/WAV trong thư mục báo cáo được chỉ định.

## Virtual audio và Google Meet

WASAPI bridge đọc/ghi thiết bị hiện có; cần cài driver virtual audio riêng để đưa đầu ra app thành micro trong Meet. Bộ cài VB-CABLE đã tải tại `.run/vb-cable/package/VBCABLE_Setup_x64.exe`, chữ ký publisher đã kiểm tra. Trên máy pilot hiện chưa có cặp endpoint này.

```powershell
.\scripts\Prepare-VirtualAudio.ps1 -OpenInstaller
```

Chấp nhận UAC, bấm **Install Driver** và khởi động lại khi thuận tiện theo hướng dẫn [VB-Audio](https://vb-audio.com/Cable/). Script không tự reboot. Sau đó:

1. App chọn mic vật lý, đầu ra **CABLE Input** (playback).
2. Meet chọn micro **CABLE Output** (recording).
3. Participant trên thiết bị khác nghe kiểm tra giọng gốc, rồi English + toggle ON/OFF, mute/unmute và rời lớp.

Một ngôn ngữ chung cho lớp. Nếu Meet vẫn chọn mic vật lý, học sinh vẫn nghe trực tiếp giọng Việt; chọn ngôn ngữ trong app không thay micro của Meet. Không chọn Stereo Mix/CABLE Output/loopback làm đầu vào ASR. VB-CABLE không được kèm trong gói phân phối; kiểm tra điều kiện của nhà cung cấp khi phát hành.

## Gói Windows native

```powershell
.\scripts\Package-AiNativeWindows.ps1 -FlutterPath 'D:\Tools\teaching-companion\flutter\bin\flutter.bat'
```

Gói ở `dist/HocLuc-AI-Native-Windows-*` chứa Flutter native, JRE jlink, Python embedded và các thư viện AI. Dùng `RUN.bat`; dừng backend checkout trước nếu cổng 47831 đang dùng. Models và driver ngoài gói; cấu hình đường model phù hợp máy nhận. CUDA dependency khiến gói lớn; không xem đây là bản nhỏ gọn đã tối ưu. Manifest ghi hash weights/dependency và nguồn model. VinAI khai báo AGPL-3.0, PhoWhisper BSD-3-Clause, Kokoro Apache-2.0 theo các model card local.

Gói này khác `Build-Windows.ps1` WebView2/Flutter web. Chưa hỗ trợ pipeline native trên Flutter web/macOS. Thử relocation trên máy hiện tại không chứng minh chạy được trên máy Windows mới hoàn toàn.

## Kiểm tra tùy chọn

```powershell
& .\backend\ai-runtime\.venv\Scripts\python.exe .\backend\ai-runtime\scripts\preflight.py
& .\backend\ai-runtime\.venv\Scripts\python.exe .\backend\ai-runtime\scripts\integration_smoke.py --wav 'D:\path\speech.wav' --report-dir '.run\my-speech-check'
```

Integration smoke gọi API Java thật, kiểm tra pipeline WAV/WebSocket và dừng worker của nó; không kiểm tra micro/playback/Meet. Báo cáo acceptance nằm trong `docs/ai-speech-acceptance.md`.

## Independent integration with develop

This branch contains only the offline speech pipeline and starts from develop; no exam database migrations or exam UI are included. Open Studio settings, Âm thanh & video, then Dịch giọng nói offline to use the translation popup. The shared media service is observed through its ChangeNotifier rather than replacing its native camera/microphone implementation. The local audio_bridge dependency is declared in frontend/pubspec.yaml. Run flutter pub get from frontend to regenerate Windows registration and CMake files, preserving camera_windows and record_windows.
