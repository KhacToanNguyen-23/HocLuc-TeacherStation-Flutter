import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

export function ensureHooksConfigured(silent = false) {
  try {
    const isGit = execSync('git rev-parse --is-inside-work-tree', {
      cwd: rootDir,
      stdio: 'pipe',
    })
      .toString()
      .trim();

    if (isGit !== 'true') {
      if (!silent) console.log('⚠️ Không phát hiện Git repository. Bỏ qua cấu hình hook.');
      return false;
    }

    // Kiểm tra cấu hình hiện tại
    let currentHooksPath = '';
    try {
      currentHooksPath = execSync('git config core.hooksPath', {
        cwd: rootDir,
        stdio: 'pipe',
      })
        .toString()
        .trim();
    } catch {
      // Chưa cấu hình
    }

    if (currentHooksPath !== '.githooks') {
      execSync('git config core.hooksPath .githooks', {
        cwd: rootDir,
        stdio: 'pipe',
      });
      if (!silent) {
        console.log('🔗 [Git Hook Setup] Đã thiết lập git config core.hooksPath .githooks');
      }
    } else if (!silent) {
      console.log('✅ [Git Hook Setup] Git hook đã được cấu hình sẵn (.githooks).');
    }

    // Đảm bảo cờ thực thi trên Git index (hữu ích cho Linux/macOS)
    try {
      execSync('git update-index --chmod=+x .githooks/pre-commit', {
        cwd: rootDir,
        stdio: 'pipe',
      });
    } catch {
      // Bỏ qua nếu chưa staged
    }

    return true;
  } catch (err) {
    if (!silent) {
      console.warn('⚠️ [Git Hook Setup] Không thể cấu hình Git hook tự động:', err.message);
    }
    return false;
  }
}

// Nếu chạy trực tiếp từ CLI
if (process.argv[1] === __filename) {
  console.log('🚀 [Setup Hooks] Đang cấu hình Git pre-commit hook...');
  const success = ensureHooksConfigured(false);
  if (success) {
    console.log('🎉 Cấu hình Git Hook thành công! Mọi thao tác commit sẽ tự động được kiểm tra kiến trúc.');
  }
}

