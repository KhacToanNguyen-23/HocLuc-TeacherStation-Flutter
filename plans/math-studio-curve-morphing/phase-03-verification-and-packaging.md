# Phase 3: Kiểm Thử, Đóng Gói .hlep & Bất Biến Kiến Trúc

## Goal
Kiểm tra toàn bộ test suites, đóng gói `.hlep` và kiểm tra 12 bất biến kiến trúc.

## Requirements
1. Chạy 5 test suites logic.
2. Đóng gói plugin và kiểm tra Schema v2.1: `node scripts/validate_plugins.mjs --fix`.
3. Kiểm tra 12 Bất biến kiến trúc: `node scripts/run_architecture_check.mjs`.

## Success Criteria
- 100% test suites logic PASS.
- `plugins/math_studio.hlep` đồng bộ tuyệt đối.
- 12/12 Invariants PASS.

