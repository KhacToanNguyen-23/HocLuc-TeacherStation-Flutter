---
title: "Frontend Deep Architecture Cleanup — Implementation Plan"
status: completed
mode: fast
spec: ./spec.md
---

# Frontend Deep Architecture Cleanup — Implementation Plan

> **Spec:** [./spec.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-deep-architecture-cleanup/spec.md)  
> **Brainstorm:** [../reports/261018-frontend-deep-architecture-cleanup-brainstorm.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/reports/261018-frontend-deep-architecture-cleanup-brainstorm.md)

## Overview

Thực thi tái kiến trúc toàn diện thư mục `frontend/lib/` theo nguyên tắc **Zero Logic Change**:
1. Xóa toàn bộ 10 tệp Dead Code / Duplicate Models (`1,063 dòng`), xóa 7 thư mục barrel vỏ rỗng trong `lib/services/` (gom `export` trực tiếp vào `lib/services/services.dart`), và xóa trường `Map<String, Uint8List> files` trong `InstalledPlugin`.
2. Phân rã 5 tệp `.dart > 900 dòng` còn lại (`pdf_dgnl_passage_overlay.dart`, `meet_automation_service.dart`, `studio_screen.dart`, `region_snipping_overlay.dart`, `pdf_annotation_exporter.dart`) xuống `< 900 dòng` bằng `part` / `part of`.
3. Nâng cấp cổng kiểm thử kiến trúc CI (`frontend/test/architecture_test.dart`): hạ trần kích thước file `.dart` xuống `<= 900 dòng` (Bất biến 6) và bổ sung Bất biến 7 (cấm file `.dart` mồ côi & cấm `Map<String, Uint8List>` trong `InstalledPlugin`).

## Phases

| # | Phase | Status | File |
|---|---|---|---|
| 01 | Purge Dead Code, Duplicate Models, Facade Subfolders & RAM `files` Map | Done | [phase-01-purge-dead-code-and-facade-folders.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-deep-architecture-cleanup/phase-01-purge-dead-code-and-facade-folders.md) |
| 02 | Decompose 5 Remaining Large Files (`953 – 1,167 lines` $\rightarrow$ `< 800 lines`) | Done | [phase-02-decompose-remaining-5-large-files.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-deep-architecture-cleanup/phase-02-decompose-remaining-5-large-files.md) |
| 03 | Tighten CI Architecture Gate (`<= 900 lines` + Invariant #7) | Done | [phase-03-tighten-ci-architecture-gate.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-deep-architecture-cleanup/phase-03-tighten-ci-architecture-gate.md) |
