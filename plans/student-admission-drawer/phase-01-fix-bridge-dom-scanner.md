# Phase 1: Fix Bridge DOM Scanner & Remove `offsetParent` Restriction

**Status:** Completed  
**Covers:** [P1] DOM Knock Detection, Fixed Position Toast Recognition  
**Risk:** Normal  

---

## Context
Popup/snackbar gõ cửa của Google Meet ("Ai đó muốn tham gia cuộc gọi này" / "Những người khác đang chờ") sử dụng CSS `position: fixed`. Theo chuẩn W3C CSSOM, mọi phần tử có `position: fixed` đều có thuộc tính `offsetParent === null`. Việc kiểm tra `if (b.offsetParent === null) return false;` khiến toàn bộ nút duyệt trong popup bị loại bỏ.
Ngoài ra, Google Meet dùng cả `<div role="button">` và `<span role="button">`.

## Tasks
1. Trong `meet_bridge_script.dart`:
   - Tại `scanHandsAndKnocks()`:
     - Query selector: `document.querySelectorAll('button, [role="button"]')`.
     - Bỏ kiểm tra `b.offsetParent === null`. Chỉ kiểm tra `if (b.disabled || b.getAttribute('aria-disabled') === 'true') return false;`.
     - Tìm từ khóa 'cho phép', 'chấp nhận', 'cho vào', 'admit', 'allow'.
   - Tại `window.MeetBridge.admitAll()`:
     - Tương tự, bỏ kiểm tra `b.offsetParent === null`.
     - Query selector `button, [role="button"]`.
     - Bấm click trên tất cả các nút duyệt tìm thấy.
2. Kiểm tra `meet_bridge_parser_test.dart` đảm bảo script biên dịch và chứa các từ khóa cần thiết.
