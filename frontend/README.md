# Flutter UI của Mộc Teaching Studio

Hướng dẫn chạy Java service, Flutter preview và desktop Windows/macOS nằm ở [README của khung app](../README.md).

`lib/main.dart` chứa shell giao diện; `lib/models` chứa trạng thái bài; `lib/services` gọi Java; `lib/widgets` nhúng host Fastboard qua iframe/WebView2/WKWebView.

Bảng nháp là demo. Camera/mic ảo, audio capture và AI streaming chưa được triển khai. Flutter native runners có source nhưng chưa được nghiệm thu trên Windows/macOS. Bản Windows portable dùng Flutter web trong host WinForms/WebView2, có Java/runtime đi kèm; cách build và chạy nằm trong README của khung app.
