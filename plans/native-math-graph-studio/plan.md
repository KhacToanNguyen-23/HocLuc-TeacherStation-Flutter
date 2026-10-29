# Plan v2: Bỏ WebView cho plugin Math Studio — giữ UI + giữ cơ chế plugin + zero hardcode toán

Mode: Hard (supersedes the earlier "native math in lib/" draft, which violated AGENTS.md invariant 1)
Risk: high-risk — adds a new plugin runtime kind (manifest schema change), new native dependency (`flutter_js`/QuickJS), touches plugin_engine core.

## Ràng buộc đã chốt với user
1. Giữ nguyên giao diện hiện tại (cửa sổ modal, 4 tab Đồ thị / BBT / Tích phân / Hình 3D, bố cục Editorial 32%:68%, ô nhập hàm, Inspector SGK).
2. Giữ cơ chế plugin (`.hlep`, manifest v2.x, marketplace, cập nhật nóng).
3. `frontend/lib/` **không chứa bất kỳ kiến thức toán nào** (không CAS, không preset hàm, không nhãn SGK, không tên môn). Host chỉ có thành phần generic.

## Kiến trúc
```
plugins/math_studio/                 (toàn bộ kiến thức toán nằm ở đây)
├── manifest.json                    ui.runtime = "native", logic.entry, ui.layout
├── logic/main.js                    bundle IIFE: CAS + state + dựng view-model + dựng scene (tái dùng core/*.js)
└── ui/layout.json                   cây UI khai báo (tab, ô nhập, chip, danh sách, canvas)

frontend/lib/features/plugin_engine/
├── services/native_plugin_runtime.dart   QuickJS (flutter_js) — chạy logic/main.js, cầu nối message tương thích HocLuc SDK
├── domain/models/ui_node.dart            schema node generic
└── presentation/native/
    ├── declarative_view.dart             render node: row/column/tabs/text_input/chip/list/card/latex/scene
    ├── scene_canvas.dart                 CustomPainter vẽ lệnh vector (polyline, point, dashed, text, rect)
    └── native_plugin_host.dart           thay FlatHost khi ui.runtime == "native"
```
- Host không biết "đồ thị", "đạo hàm", "cực trị": chỉ nhận cây node + lệnh vẽ, gửi lại sự kiện (`input`, `tap`, `pan`, `zoom`).
- Pan/zoom: host áp transform cục bộ lên scene (mượt 120 FPS), đồng thời gửi viewport (throttle) để plugin lấy mẫu lại.
- Plugin khác (casio, english…) vẫn chạy `FlatHost`/WebView, không đổi.

## Phases
| # | Nội dung | Gate |
|---|----------|------|
| 0 | Spike: thêm `flutter_js`, bundle `core/*.js` thành IIFE (esbuild trong `scripts/`), chạy trong QuickJS; đo thời gian + so khớp kết quả với Node | Go/No-go: QuickJS chạy được trên Windows build, phân tích hàm < 5 ms |
| 1 | Manifest v2.2 (additive: `ui.runtime`, `logic.entry`, `ui.layout`) + cập nhật validator, `PluginManifest`, architecture test | 12/12 invariants |
| 2 | Runtime generic: `NativePluginRuntime`, `ui_node`, `DeclarativeView`, `SceneCanvas`, host SDK bridge (sticker/ghim bảng giữ nguyên) | widget tests; không có từ khoá toán trong lib/ |
| 3 | Port tab Đồ thị: state + Inspector SGK + liên kết hai chiều (pan/pulse) → `logic/main.js` + `layout.json` | so ảnh chụp với UI hiện tại |
| 4 | Port BBT, Tích phân, Hình 3D (chiếu 3D→2D tính trong plugin, xuất scene) | parity từng tab |
| 5 | Xuất/ghim vào bảng: scene → PNG qua `PictureRecorder` (generic) | sticker hoạt động |
| 6 | Bỏ JSXGraph + `vendor/`, đóng gói `.hlep`, `validate_plugins`, `flutter test`, `flutter analyze` | CI gate |

## Rủi ro chính
| Rủi ro | Giảm thiểu |
|--------|-----------|
| JSXGraph/DOM không chạy được trong QuickJS | Thay bằng scene protocol; plugin tự tính trục/lưới/tick |
| Công thức LaTeX/STIX | Node `latex` generic dùng `flutter_math_fork` (chuỗi LaTeX do plugin gửi) |
| Phạm vi lớn (~5k dòng JS + 1.2k CSS cần dựng lại) | Phase 0 là cổng go/no-go; làm tab Đồ thị trước, mỗi tab nghiệm thu riêng |
| Thêm dependency native | `flutter pub add` cần mạng (chạy ngoài sandbox, user duyệt) |

## Verification mỗi phase
`node scripts/validate_plugins.mjs` · `flutter test test/architecture_test.dart` · `flutter analyze --no-fatal-infos` · `node scripts/package_plugin.mjs math_studio`
