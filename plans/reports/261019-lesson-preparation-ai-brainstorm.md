# Brainstorm: AI trong Soạn bài

Date: 2026-10-19

## User's Direction

Chuyển STT–translation–TTS sang soạn bài. Đầu vào video/ghi âm hoặc script/prompt; đầu ra giáo án, bài giảng, animation có giọng đọc. Hỗ trợ hai loại animation, làm template đơn giản trước. Người dùng chọn ưu tiên giọng tiếng Anh với model hiện có. Mọi nghiệp vụ điều khiển qua HocLuc.

## Ideas Explored

1. Video → STT có timestamp → giáo án/storyboard → animation tiếng Anh: tận dụng cả ba model; cần thêm authoring và renderer.
2. Script → scene → TTS → render: ít phụ thuộc nhất, không cần STT; dịch chỉ khi script Việt cần lời đọc Anh.
3. Prompt → authoring → scene template: có thể chỉnh, render lặp lại và kiểm soát nội dung. LLM authoring là thành phần khác model dịch.
4. Prompt → video sinh cảnh/nhân vật: để giai đoạn sau; template MVP không phụ thuộc chọn provider/cost.
5. Chỉ dùng WebView các dịch vụ bên ngoài: không chọn làm nền tảng vì khó quản lý asset/job, retry và quyền; ưu tiên API/worker được app điều phối.
6. Teacher view + audience output: tái sử dụng notes có sẵn, bổ sung đường chia sẻ thực và artifact học sinh tách biệt.

## Code audit (snapshot, không phải live acceptance)

| Phần | Bằng chứng | Kết luận |
|---|---|---|
| Planning | `backend/api/src/main/java/vn/teaching/service/PlanningService.java` | Có CRUD và lưu payload; `cloneToClassroom` ghi `lesson.json` nội bộ, không đăng Google Classroom. |
| Notes | `frontend/lib/features/studio_board/presentation/studio/studio_speaker_notes_bar.dart`, `presentation/screens/studio_screen.dart:569` | Có notes theo trang ngay trong app, board view; chưa cần tạo lại UI notes. |
| Persistence | `studio_state.dart:607`, `:743`; `studio_screen_actions.dart:11` | Có serialize và lưu planning; cập nhật notes trong state không tự chứng minh đã autosave backend. |
| Privacy | `presentation_surface.dart:72`, `meet_screen_share_script.dart:23` | RepaintBoundary không tự tạo stream Meet. Whole-window/screen capture có thể lộ notes. Nhãn riêng tư hiện tại vượt quá bằng chứng. |
| Export | `pdf_annotation_handout_exporter.dart:173` | Handout hiện có chứa pageNotes; không lấy làm bản upload mặc định. |
| Google | `GoogleIntegrationController.java`, `GoogleConnectionService.java:13` | Có lớp/roster/Meet/lịch; chưa có Drive upload/courseworkmaterials scope hay publish pipeline. |
| AI | `backend/ai-runtime/models.py:95-144`, `server.py:171-202` | VI STT, VI→EN, EN TTS; file preview WAV ngắn, không phải job video dài/authoring. |

Không có `graphify-out/graph.json` và không tìm thấy lệnh graphify trong PATH. Đợt review này đối chiếu trực tiếp source và call sites; không dựng đồ thị mới hoặc tuyên bố có graph evidence.

## Risks

- Ghi chú riêng lẫn narration/student artifacts hoặc lọt vào screen share.
- Dùng model dịch làm bộ sinh giáo án, hoặc hứa giọng/ngôn ngữ chưa hỗ trợ.
- Retry upload/post gây trùng hoặc báo đăng xong khi học sinh chưa mở được file.
- Nạp nhiều model/render cùng lúc vượt bộ nhớ; long media không phù hợp endpoint preview cũ.

## Open Decisions

- Cloud AI chưa được cho phép: mặc định tắt và local-first; lựa chọn provider/model authoring cần benchmark.
- Budget/quota cho video AI nâng cao sẽ chốt trước khi bật adapter, không chặn MVP template.

## Handoff

Spec: `plans/lesson-preparation-ai/spec.md`. Plan: `plans/lesson-preparation-ai/plan.md`.
Đây là tài liệu thiết kế và review code; chưa triển khai các pipeline mới hay sửa bảo đảm private screen-share.

## Verification snapshot

- `node scripts/setup_hooks.mjs`: hooks đã trỏ `.githooks`; không giữ thay đổi file mode/staged do setup tạo ra.
- `node scripts/validate_plugins.mjs`: 2 plugins hợp lệ và đồng bộ.
- `flutter test test/architecture_test.dart test/features/studio_board/studio_speaker_notes_bar_test.dart test/features/classroom_meet/lesson_planning_test.dart`: 19 tests passed (gồm 12 invariants kiến trúc).
- `flutter analyze --no-fatal-infos`: No issues found.
- Không chạy inference, benchmark authoring, render video, consent mới hoặc publish Google thật. Widget tests không chứng minh stream Meet riêng tư.
- Snapshot đang ở `feat/new-whiteboard-pen`; không tự đổi nhánh trong lượt phân tích này. Giữ nguyên các thư mục nguồn/cache chưa theo dõi sẵn có.
