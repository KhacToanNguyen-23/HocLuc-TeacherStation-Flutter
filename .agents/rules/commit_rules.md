# Git Commit Rules

1. **Chỉ commit file code (Only commit code files):** Không được phép commit các file cấu hình môi trường, script setup cá nhân (như `setup_flutter.ps1`), hoặc các file chứa credential, biến môi trường `.env`.
2. Tất cả các SDK tải về (ví dụ `.sdk/`) phải được đưa vào `.gitignore`.
