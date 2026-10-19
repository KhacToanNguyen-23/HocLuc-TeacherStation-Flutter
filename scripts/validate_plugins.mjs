import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const pluginsDir = path.join(rootDir, 'plugins');

const isFixMode = process.argv.includes('--fix');

const VALID_PLACEMENTS = new Set([
  'floating_window',
  'bottom_drawer',
  'drawer_panel',
  'right_panel',
]);

const VALID_TOOL_ACTIONS = new Set([
  'snip_region',
  'toggle_tool',
  'toggle_setting',
  'quick_input',
  'rpc_event',
]);

const IGNORED_DIRS = new Set([
  '__pycache__',
  '.venv',
  'node_modules',
  '.git',
]);

function getFilesRecursively(dir, relative = '') {
  const result = [];
  if (!fs.existsSync(dir)) return result;

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (IGNORED_DIRS.has(entry.name)) continue;

    const fullPath = path.join(dir, entry.name);
    const relPath = path.join(relative, entry.name).replace(/\\/g, '/');

    if (entry.isDirectory()) {
      result.push(...getFilesRecursively(fullPath, relPath));
    } else {
      const stat = fs.statSync(fullPath);
      result.push({ fullPath, relPath, mtimeMs: stat.mtimeMs });
    }
  }
  return result;
}

function runPackagePlugin(pluginName) {
  console.log(`📦 [Auto-Fix] Đang đóng gói lại plugins/${pluginName}.hlep...`);
  const packageScript = path.join(__dirname, 'package_plugin.mjs');
  const res = spawnSync(process.execPath, [packageScript, pluginName], {
    cwd: rootDir,
    stdio: 'inherit',
  });
  return res.status === 0;
}

function validatePluginDir(pluginName, errors, warnings, outOfSyncPlugins) {
  const dirPath = path.join(pluginsDir, pluginName);
  const manifestPath = path.join(dirPath, 'manifest.json');
  const hlepPath = path.join(pluginsDir, `${pluginName}.hlep`);

  // 1. Kiểm tra manifest.json
  if (!fs.existsSync(manifestPath)) {
    errors.push({
      plugin: pluginName,
      code: 'MISSING_MANIFEST',
      message: `Thiếu file manifest.json tại ${dirPath}`,
      fix: `Tạo file manifest.json theo chuẩn Schema v2.1`,
    });
    return;
  }

  let manifest;
  try {
    const raw = fs.readFileSync(manifestPath, 'utf8');
    manifest = JSON.parse(raw);
  } catch (err) {
    errors.push({
      plugin: pluginName,
      code: 'INVALID_JSON',
      message: `File manifest.json không đúng định dạng JSON: ${err.message}`,
      fix: `Sửa cú pháp JSON trong ${manifestPath}`,
    });
    return;
  }

  // 2. Kiểm tra các trường bắt buộc
  for (const field of ['id', 'name', 'version']) {
    if (!manifest[field] || typeof manifest[field] !== 'string') {
      errors.push({
        plugin: pluginName,
        code: 'SCHEMA_VIOLATION',
        message: `Trường "${field}" trong manifest.json là bắt buộc và phải là string`,
        fix: `Bổ sung "${field}" vào manifest.json`,
      });
    }
  }

  if (manifest.id && !manifest.id.startsWith('com.hocluc.plugin.')) {
    warnings.push({
      plugin: pluginName,
      code: 'ID_NAMING_CONVENTION',
      message: `Plugin ID "${manifest.id}" nên bắt đầu bằng "com.hocluc.plugin." để tránh xung đột`,
    });
  }

  // 3. Kiểm tra icon
  const iconRel = manifest.icon || 'icon.png';
  const iconPath = path.join(dirPath, iconRel);
  if (!fs.existsSync(iconPath)) {
    errors.push({
      plugin: pluginName,
      code: 'MISSING_ICON',
      message: `Không tìm thấy file icon tại ${iconPath}`,
      fix: `Đặt file icon.png (64x64 hoặc 128x128) vào ${dirPath}`,
    });
  }

  // 4. Kiểm tra UI entry & placement
  const uiPlacement = manifest.ui?.placement || manifest.placement || 'floating_window';
  if (!VALID_PLACEMENTS.has(uiPlacement)) {
    errors.push({
      plugin: pluginName,
      code: 'INVALID_PLACEMENT',
      message: `ui.placement "${uiPlacement}" không hợp lệ. Phải là một trong: ${[...VALID_PLACEMENTS].join(', ')}`,
      fix: `Cập nhật ui.placement trong manifest.json`,
    });
  }

  const uiEntryRel = manifest.ui?.entry || manifest.main || 'ui/index.html';
  const uiEntryPath = path.join(dirPath, uiEntryRel);
  if (!fs.existsSync(uiEntryPath)) {
    errors.push({
      plugin: pluginName,
      code: 'MISSING_UI_ENTRY',
      message: `Không tìm thấy file entrypoint giao diện tại ${uiEntryPath}`,
      fix: `Đảm bảo file ${uiEntryRel} tồn tại hoặc sửa trường ui.entry / main trong manifest.json`,
    });
  }

  // 5. Kiểm tra Backend (nếu có)
  if (manifest.backend) {
    const backendEntryRel = manifest.backend.entry || manifest.backendExecutable;
    if (backendEntryRel) {
      const backendEntryPath = path.join(dirPath, backendEntryRel);
      if (!fs.existsSync(backendEntryPath)) {
        errors.push({
          plugin: pluginName,
          code: 'MISSING_BACKEND_ENTRY',
          message: `Không tìm thấy file backend entry tại ${backendEntryPath}`,
          fix: `Kiểm tra đường dẫn backend.entry trong manifest.json`,
        });
      }
    }
  }

  // 6. Kiểm tra Contributes Tools (nếu có)
  const tools = manifest.contributes?.tools;
  if (Array.isArray(tools)) {
    for (const tool of tools) {
      if (!tool.id || !tool.label || !tool.action) {
        errors.push({
          plugin: pluginName,
          code: 'INVALID_TOOL_CONFIG',
          message: `Công cụ trong contributes.tools thiếu id, label hoặc action`,
          fix: `Khai báo đầy đủ id, label, action cho tool: ${tool.id || 'unnamed'}`,
        });
      } else if (!VALID_TOOL_ACTIONS.has(tool.action)) {
        errors.push({
          plugin: pluginName,
          code: 'INVALID_TOOL_ACTION',
          message: `Tool action "${tool.action}" không hợp lệ. Phải là một trong: ${[...VALID_TOOL_ACTIONS].join(', ')}`,
          fix: `Sửa action của tool "${tool.id}" trong manifest.json`,
        });
      }
    }
  }

  // 7. Kiểm tra tệp .hlep và độ tươi (Freshness Check)
  if (!fs.existsSync(hlepPath)) {
    errors.push({
      plugin: pluginName,
      code: 'MISSING_HLEP',
      message: `Gói nén ${pluginName}.hlep chưa tồn tại!`,
      fix: `node scripts/package_plugin.mjs ${pluginName}`,
    });
    outOfSyncPlugins.add(pluginName);
  } else {
    const hlepStat = fs.statSync(hlepPath);
    const files = getFilesRecursively(dirPath);

    let isOutOfSync = false;
    let latestModifiedFile = null;

    for (const file of files) {
      // Cho phép lệch 1500ms do độ phân giải thời gian của file system
      if (file.mtimeMs > hlepStat.mtimeMs + 1500) {
        isOutOfSync = true;
        if (!latestModifiedFile || file.mtimeMs > latestModifiedFile.mtimeMs) {
          latestModifiedFile = file;
        }
      }
    }

    if (isOutOfSync) {
      errors.push({
        plugin: pluginName,
        code: 'OUT_OF_SYNC_HLEP',
        message: `Mã nguồn plugin "${pluginName}" đã bị sửa đổi (ví dụ: ${latestModifiedFile?.relPath}) nhưng file "${pluginName}.hlep" chưa được đóng gói lại!`,
        fix: `node scripts/package_plugin.mjs ${pluginName}`,
      });
      outOfSyncPlugins.add(pluginName);
    }
  }
}

function checkOrphanPackages(errors) {
  if (!fs.existsSync(pluginsDir)) return;

  const entries = fs.readdirSync(pluginsDir);
  for (const entry of entries) {
    if (entry.endsWith('.hlep')) {
      const pluginName = entry.slice(0, -5);
      const matchingFolder = path.join(pluginsDir, pluginName);
      if (!fs.existsSync(matchingFolder) || !fs.statSync(matchingFolder).isDirectory()) {
        errors.push({
          plugin: pluginName,
          code: 'ORPHAN_HLEP',
          message: `Phát hiện gói mồ côi "${entry}". Thư mục nguồn "plugins/${pluginName}/" không tồn tại!`,
          fix: `Xóa file mồ côi: git rm plugins/${entry}`,
        });
      }
    }
  }
}

function main() {
  console.log('🔍 [Plugin Validator] Đang quét toàn bộ plugins và kiểm tra tính toàn vẹn...');
  const startTime = Date.now();

  const errors = [];
  const warnings = [];
  const outOfSyncPlugins = new Set();

  if (!fs.existsSync(pluginsDir)) {
    console.error(`❌ Thư mục plugins không tồn tại tại: ${pluginsDir}`);
    process.exit(1);
  }

  // 1. Quét các thư mục plugin
  const entries = fs.readdirSync(pluginsDir, { withFileTypes: true });
  const pluginFolders = entries
    .filter((e) => e.isDirectory() && !IGNORED_DIRS.has(e.name) && !e.name.startsWith('.'))
    .map((e) => e.name);

  for (const folder of pluginFolders) {
    validatePluginDir(folder, errors, warnings, outOfSyncPlugins);
  }

  // 2. Quét gói mồ côi
  checkOrphanPackages(errors);

  // 3. Xử lý cờ --fix nếu có lỗi out-of-sync
  if (isFixMode && outOfSyncPlugins.size > 0) {
    console.log(`\n🔧 [Auto-Fix] Phát hiện ${outOfSyncPlugins.size} plugin cần đóng gói lại...`);
    for (const pluginName of outOfSyncPlugins) {
      runPackagePlugin(pluginName);
    }
    console.log('🔄 Đang kiểm tra lại sau khi auto-fix...');
    // Chạy lại kiểm tra sau khi fix
    errors.length = 0;
    warnings.length = 0;
    outOfSyncPlugins.clear();
    for (const folder of pluginFolders) {
      validatePluginDir(folder, errors, warnings, outOfSyncPlugins);
    }
    checkOrphanPackages(errors);
  }

  const durationMs = Date.now() - startTime;

  // 4. In cảnh báo (Warnings)
  if (warnings.length > 0) {
    console.log('\n⚠️ [CẢNH BÁO KIẾN TRÚC]:');
    for (const w of warnings) {
      console.log(`  - [${w.plugin}] (${w.code}): ${w.message}`);
    }
  }

  // 5. In lỗi (Errors)
  if (errors.length > 0) {
    console.error(`\n❌ [PHÁT HIỆN ${errors.length} LỖI VI PHẠM PLUGIN] (${durationMs}ms):`);
    for (const err of errors) {
      console.error(`\n  🔴 [${err.plugin}] ${err.code}: ${err.message}`);
      if (err.fix) {
        console.error(`     👉 KHẮC PHỤC: ${err.fix}`);
      }
    }
    console.error('\n💡 GỢI Ý: Chạy "node scripts/validate_plugins.mjs --fix" để tự động sửa các gói bị out-of-sync.\n');
    process.exit(1);
  }

  console.log(`✅ [Plugin Validator] Tất cả plugin đạt chuẩn Schema v2.1 và đồng bộ 100%! (${pluginFolders.length} plugins, ${durationMs}ms)`);
  process.exit(0);
}

main();

