# Scripts trong repository

Thư mục này chứa các công cụ dòng lệnh hỗ trợ phát triển và vận hành repository. Tên thư mục mô tả mục đích; tên file dùng kebab-case, riêng module Python dùng snake_case để có thể import theo quy ước Python. Script không tự chạy chỉ vì nằm ở đây: nó được gọi bởi GitHub Actions, Git hook, script build khác, hoặc do developer chạy lệnh được ghi dưới đây.

## Nhóm script

| Thư mục | Nội dung | Cách chạy / thời điểm chạy |
| --- | --- | --- |
| `ai/` | Cài Python runtime AI, xuất model INT8, tạo manifest và đóng gói bản Windows native. | Chạy thủ công theo hướng dẫn trong `docs/ai-speech-setup.md`; không chạy trong CI thông thường. |
| `audio/` | Tải và kiểm tra chữ ký bộ cài VB-CABLE; có thể mở trình cài tương tác. | Chạy thủ công trên máy Windows cần thiết lập audio; `-OpenInstaller` yêu cầu UAC. |
| `build/` | Kiểm tra font trong Flutter web build và smoke test gói Windows đã tạo. | Font checker được gọi bởi `Build-Windows.ps1`; package smoke test chạy thủ công sau khi tạo bundle. |
| `checks/` | Kiểm tra bất biến kiến trúc; giữ một kiểm thử hợp đồng service đời cũ. | Architecture check có lệnh `node scripts/checks/run-architecture-check.mjs`; CI hiện dùng `flutter test test/architecture_test.dart`. `legacy-companion-service-contract.mjs` không thuộc CI hiện hành và cần JAR legacy để chạy. |
| `dictionaries/` | Sinh dữ liệu từ điển tiếng Việt và lexicon CEFR từ nguồn đã chuẩn bị. | Chạy thủ công khi cập nhật dữ liệu; xem `--help` hoặc thông báo tham số của từng script. |
| `exam/` | Build và chạy nền tảng thi trên máy local. | Chạy thủ công: `./scripts/exam/start-exam-platform.ps1`; xem `docs/exam-platform.md`. |
| `git/` | Cấu hình `core.hooksPath` để Git gọi `.githooks/`. | Chạy một lần sau khi clone: `node scripts/git/setup-hooks.mjs`. |
| `plugins/` | Kiểm tra manifest/source/archive và đóng gói plugin `.hlep`. | CI gọi validator ở chế độ source-only; chạy đầy đủ trước khi phát hành. Lệnh: `node scripts/plugins/validate-plugin-packages.mjs [--fix]` và `node scripts/plugins/package-plugin.mjs <plugin-folder>`. |
| `tests/` | Bộ kiểm thử hiện hành cho dictionary; các test Math Studio cũ được lưu trong `tests/legacy/`. | Chạy `node --test scripts/tests/dictionaries/vietnamese-dictionary.test.cjs` hoặc `python -m unittest scripts.tests.dictionaries.test_generate_cefr_lexicon`. |

## Các lệnh CI chính

Workflow `.github/workflows/ci-frontend.yml` kiểm tra plugin source, chạy browser tests, `flutter analyze`, kiểm thử kiến trúc và `flutter test`; job Windows biên dịch ứng dụng native. Các bước này được khai báo tường minh trong workflow. Thay đổi dưới `scripts/**` cũng kích hoạt workflow.

## Ghi chú

- `checks/legacy-companion-service-contract.mjs` còn được giữ để tham khảo/kiểm thử hệ thống legacy; hiện nó trông đợi artifact `backend/api/service/target/companion-service-0.1.0.jar`, nên không đại diện cho backend hiện hành.
- `tests/legacy/math-studio/` chứa các test độc lập viết cho API Math Studio cũ đã bị thay thế. Chúng không được gọi trong CI hiện hành và cần được chuyển đổi nếu muốn dùng lại.
- Test script là mã kiểm thử, không phải script triển khai. Chúng chỉ chạy tự động nếu được gọi bởi workflow hoặc lệnh test tương ứng.
- Các script không cần Node dependencies riêng khi dùng built-in modules; riêng các script Python cần môi trường Python phù hợp.
