# Phase 3: Verification & Architecture Gate

**Objective:** Kiểm thử toàn diện tất cả các khía cạnh logic, kiểm tra 12/12 bất biến kiến trúc sạch sẽ, và xác minh thực tế đồ thị từ panel ra bảng phấn.

---

## 1. Automated Test Suites
1. **Plugin Schema & Archive Freshness:**
   - Command: `node scripts/validate_plugins.mjs`
   - Target: 3/3 plugins valid, 0 lỗi, `.hlep` đồng bộ Schema v2.1.
2. **Math Studio Core Engine Tests:**
   - Command: `node scripts/test_math_studio.mjs`
   - Target: 7/7 tests pass 100% (cực trị, tiệm cận, tích phân, hàm số).
3. **App Logic Simulation:**
   - Command: `node scripts/test_app_logic.mjs`
   - Target: 5/5 logic tests pass 100%.
4. **Architecture Gate (12/12 Invariants):**
   - Command: `node scripts/run_architecture_check.mjs`
   - Target: 12/12 Bất biến kiến trúc ĐẠT 100% (Zero hardcoded plugin IDs, zero direct imports, process dynamic ports, anti-god class <= 900 lines).

---

## 2. Manual Visual Verification Checklist
- [ ] Mở Math Studio $\rightarrow$ Nhập `y = x^2 - 2` $\rightarrow$ Tích phân $a = -1, b = 2$ $\rightarrow$ Bấm "Xong".
- [ ] Kiểm tra đồ thị trên Bảng phấn: Đường cong đỏ chuẩn SGK, 2 mút cận đỏ, diện tích đỏ ấm trong suốt, cực trị xanh navy viền trắng $\rightarrow$ giống 100% panel.
- [ ] Click vào đồ thị: Khung cam và 8 chốt hiện lên; thanh công cụ nổi nằm ngang phía trên.
- [ ] Kéo chốt góc: Đồ thị phóng to/thu nhỏ mượt mà.
- [ ] Kéo chốt xoay đỉnh: Đồ thị xoay quanh tâm; thanh công cụ nổi vẫn giữ phương ngang.
- [ ] Click ra ngoài mặt bảng: Viền cam và 8 chốt ẩn đi hoàn toàn.
- [ ] Click lại vào đồ thị: Viền cam và 8 chốt xuất hiện trở lại; tiếp tục kéo co dãn mượt mà (không bị đơ, không bị lỗi lặp lần 2).

