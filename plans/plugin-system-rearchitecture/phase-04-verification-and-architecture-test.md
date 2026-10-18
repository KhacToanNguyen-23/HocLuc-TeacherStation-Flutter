# Phase 04: Verification & Architecture Gate

**Goal:** Kiểm thử toàn diện từ Backend Spring Boot đến Frontend Flutter, xác nhận luồng tải qua Internet, cài đặt vào máy, mở cửa sổ nổi và ghim kết quả hoạt động hoàn hảo; khóa chặt 5/5 bất biến kiến trúc.

---

## 1. Scope & Action Items

1. **Kiểm thử Backend:**
   - Chạy `mvn test` trên `backend/api/` xác nhận controller và service marketplace pass 100%.
2. **Kiểm thử Frontend:**
   - Chạy `flutter test test/architecture_test.dart` xác nhận 5/5 bất biến đạt 100%.
   - Chạy toàn bộ test suite frontend (`flutter test`).
3. **Kiểm thử người dùng cuối trên ứng dụng đang chạy:**
   - Mở Teacher Station -> Mở Kho Tiện ích -> Thấy Máy Tính Casio với thông tin từ Backend -> Bấm Cài đặt -> Mở cửa sổ nổi -> Tính toán và dán kết quả lên bảng phấn.

---

## 2. Verification Criteria
- [ ] Backend Spring Boot test: PASSED.
- [ ] Frontend Architecture Invariants test: 5/5 PASSED.
- [ ] Toàn bộ test suite không có lỗi nào.
