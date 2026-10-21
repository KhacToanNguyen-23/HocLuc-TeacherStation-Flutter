# Phase 01 — Nền tảng dữ liệu và vòng đời

Status: Code implemented; automated verification tracked in plan.md, device/manual acceptance pending. Covers R02, R04, prerequisites R03/R05.

## Công việc

1. Trace reproduction Bad state qua load/auth/autosave/Studio pop/revision; ghi exact root cause trước chọn fix. Có test lỗi thực trước sửa; không xóa guard hoặc set dirty=false giả.
2. Liệt kê mọi writer tới PlanningService; thiết kế common lock và serialized atomic scoped merge + revision. Guard ở controller không thay common lock. Test prep/board xen kẽ và cùng base revision.
3. Migration stable page/activity IDs, cue mapping, backup và idempotency; provenance giữ. Không ghi đè board snapshot từ giáo án.
   Tách board locator và PDF locator `documentId/contentFingerprint/pageIndex`; file thay thế yêu cầu explicit remap. Derived presentation snapshot có origin/source revision, preview/teach-again không tự tích lũy trang vào canonical.
4. State machine load/save/offline/conflict/auth; account-isolated local recovery, load failure không tạo blank saved state. Session restoration giữ tương thích đã có; verified identity server bắt buộc.
5. Return contract Studio planning mode: await save/discard/cancel, explicit reload/reconcile parent sau pop; UI retry thay raw error.

## Verification / exit gate

A06–A14 pass gồm mỗi nhánh board 20 vòng, crash/network recovery và concurrency. Không đổi schema production trước backup/restore rehearsal. Artifacts: root-cause note, migration fixtures và test evidence. Đã có code và kiểm thử tự động; không tự coi callback tests là nghiệm thu thao tác whiteboard thật.
