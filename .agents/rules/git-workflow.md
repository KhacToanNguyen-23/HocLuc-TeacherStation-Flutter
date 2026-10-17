# Git Workflow & Branching Rules

## QUY TẮC BẮT BUỘC KHI PUSH CODE:
1. **KHÔNG BAO GIỜ PUSH TRỰC TIẾP LÊN `develop` HOẶC `main`**:
   - Dù người dùng có nói "push lên develop" hay "sync code", agent **tuyệt đối không chạy `git push origin develop`** hoặc merge trực tiếp vào nhánh `develop`/`main`.
2. **LUÔN LUÔN TẠO HOẶC SỬ DỤNG NHÁNH RIÊNG (FEATURE / FIX BRANCH)**:
   - Mọi commit mới phải nằm trên một nhánh nhánh riêng (ví dụ: `feature/<name>`, `fix/<name>`).
   - Push nhánh riêng đó lên remote: `git push origin <feature-branch>`.
3. **MỞ PULL REQUEST (PR)**:
   - Sau khi push nhánh riêng lên remote, cung cấp đường link và hướng dẫn để người dùng mở Pull Request (PR) merge từ nhánh đó vào `develop`.
