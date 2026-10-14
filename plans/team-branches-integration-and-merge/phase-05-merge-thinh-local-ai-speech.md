# Phase 05: Merge nhánh AI Dịch giọng nói Offline

## Mục tiêu
Tích hợp plugin native C++ Windows `audio_bridge`, Python AI runtime server và widget điều khiển âm thanh trên Studio.

## Các bước thực hiện
1. Thực hiện merge:
   ```powershell
   git merge origin/feat/local-ai-speech-translation --no-ff -m "merge: integrate local AI speech translation runtime from Nguyen Duc Thinh"
   ```
2. Hòa giải conflict ở `frontend/pubspec.lock` (nếu có):
   ```powershell
   cd frontend
   flutter pub get
   git add pubspec.lock
   git commit --no-edit
   ```
3. Kiểm tra CMake native:
   - Đảm bảo `plugins/audio_bridge` và `camera_windows` cùng có mặt trong cấu hình Windows plugin registrant.
4. Chạy test xác nhận:
   ```powershell
   flutter test test/audio_translation_test.dart test/audio_translation_preview_test.dart
   ```
