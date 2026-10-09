HocLuc Teacher 0.1 - Windows x64

Double-click HocLuc-Teacher.exe để mở app.
Giữ toàn bộ các file/thư mục cạnh exe khi sao chép app.
Bài và cấu hình: %LOCALAPPDATA%\HocLuc-Teacher\data
Đóng cửa sổ app sẽ dừng Java service của app.

Double-click HocLuc-Teacher.exe to open the app.
Keep all files/folders next to the exe; do not move only the exe.
No Java, Flutter, Node, Maven or Visual Studio installation is needed to RUN it.
Target: Windows 10/11 x64 with .NET Framework 4.8 (included with current Windows 10/11).

Lesson/settings: %LOCALAPPDATA%\HocLuc-Teacher\data
Logs: %LOCALAPPDATA%\HocLuc-Teacher\logs\desktop.log
Closing the app stops its private Java service. It does not stop development preview services.

UI/renderer/fonts are bundled and can open offline. Flat/Netless sessions need Internet.
This is Flutter web in a native WebView2 desktop window, with a bundled Java runtime.
Virtual camera/mic and AI streaming are still not implemented in this prototype.

The executable is unsigned. No administrator privileges are required to run the portable folder.
The source project is separate; this folder contains only the runtime bundle.
