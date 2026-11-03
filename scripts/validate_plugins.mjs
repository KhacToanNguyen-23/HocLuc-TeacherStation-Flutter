import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const pluginsDir = path.join(rootDir, 'plugins');

const isFixMode = process.argv.includes('--fix');
const sourceOnly = process.argv.includes('--source-only');

const VALID_PLACEMENTS = new Set([
  'floating_window',
  'modal',
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
const REQUIRED_MANIFEST_SCHEMA = 'https://hocluc.edu.vn/schemas/plugin-manifest-v2.1.json';
const FIXED_PORT_PATTERN = /(?::18888\b|(?<![\d.])18888(?![\d.])|\b(?:localhost|127\.0\.0\.1):\d{2,5}\b|\bport\s*[:=]\s*\d{2,5}\b|\bport\s*\|\|\s*['"]\d{2,5}['"])/i;

const IGNORED_DIRS = new Set([
  '__pycache__',
  '.venv',
  '.dart_tool',
  'node_modules',
  'build',
  'coverage',
  'test',
  'tests',
  '.git',
  '.cache',
]);

const TEXT_EXTENSIONS = new Set([
  '.json', '.js', '.mjs', '.cjs', '.html', '.css',
  '.py', '.txt', '.md', '.yaml', '.yml', '.svg'
]);

function normalizeEntryBytes(bytes, relPath) {
  const ext = path.extname(relPath).toLowerCase();
  if (TEXT_EXTENSIONS.has(ext)) {
    return Buffer.from(bytes.toString('utf8').replace(/\r\n/g, '\n'), 'utf8');
  }
  return bytes;
}

function getFilesRecursively(dir, relative = '') {
  const result = [];
  if (!fs.existsSync(dir)) return result;

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (IGNORED_DIRS.has(entry.name)) continue;

    const fullPath = path.join(dir, entry.name);
    const relPath = path.join(relative, entry.name).replace(/\\/g, '/');

    if (entry.isDirectory()) {
      if (relPath === 'engine/tests' || relPath.startsWith('engine/tests/') ||
          relPath === 'engine/benchmarks' || relPath.startsWith('engine/benchmarks/')) continue;
      result.push(...getFilesRecursively(fullPath, relPath));
    } else {
      const stat = fs.statSync(fullPath);
      result.push({ fullPath, relPath, mtimeMs: stat.mtimeMs });
    }
  }
  return result;
}

function readStoredZipEntries(zipPath) {
  const buffer = fs.readFileSync(zipPath);
  const files = new Map();
  let offset = 0;
  while (offset + 30 <= buffer.length && buffer.readUInt32LE(offset) === 0x04034b50) {
    const method = buffer.readUInt16LE(offset + 8);
    if (method !== 0) throw new Error(`Unsupported compression method ${method} in ${zipPath}`);
    const size = buffer.readUInt32LE(offset + 18);
    const nameLength = buffer.readUInt16LE(offset + 26);
    const extraLength = buffer.readUInt16LE(offset + 28);
    const nameStart = offset + 30;
    const dataStart = nameStart + nameLength + extraLength;
    const name = buffer.toString('utf8', nameStart, nameStart + nameLength);
    files.set(name, buffer.subarray(dataStart, dataStart + size));
    offset = dataStart + size;
  }
  return files;
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
  if (manifest.$schema !== REQUIRED_MANIFEST_SCHEMA || !manifest.ui || !manifest.contributes || !Array.isArray(manifest.contributes.tools)) {
    errors.push({
      plugin: pluginName,
      code: 'LEGACY_MANIFEST_SCHEMA',
      message: 'Manifest phải khai báo Schema v2.1, ui lồng, và contributes.tools.',
      fix: 'Di chuyển các trường UI vào ui và khai báo contributes.tools.',
    });
  }
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
      const developmentEntryRel = manifest.backend.development_entry;
      let hasDevelopmentEntry = false;
      if (
        sourceOnly &&
        typeof developmentEntryRel === 'string' &&
        developmentEntryRel.toLowerCase().endsWith('.dart')
      ) {
        try {
          const pluginRoot = fs.realpathSync(dirPath);
          const developmentEntryPath = fs.realpathSync(
            path.resolve(dirPath, developmentEntryRel),
          );
          const relativeEntryPath = path.relative(pluginRoot, developmentEntryPath);
          const isInsidePlugin = relativeEntryPath === '' ||
            (relativeEntryPath !== '..' &&
              !relativeEntryPath.startsWith(`..${path.sep}`) &&
              !path.isAbsolute(relativeEntryPath));
          hasDevelopmentEntry = isInsidePlugin &&
            fs.statSync(developmentEntryPath).isFile();
        } catch (_) {
          hasDevelopmentEntry = false;
        }
      }
      if (!fs.existsSync(backendEntryPath) && !hasDevelopmentEntry) {
        errors.push({
          plugin: pluginName,
          code: 'MISSING_BACKEND_ENTRY',
          message: `Không tìm thấy file backend entry tại ${backendEntryPath}`,
          fix: `Kiểm tra đường dẫn backend.entry trong manifest.json`,
        });
      }
    }
    if (manifest.backend.port != null) {
      errors.push({ plugin: pluginName, code: 'FIXED_BACKEND_PORT', message: 'Không khai báo cổng cố định trong backend; Host cấp cổng lúc chạy.' });
    }
    if (manifest.backend.type === 'python' && !fs.existsSync(path.join(dirPath, 'engine', 'requirements.txt'))) {
      errors.push({ plugin: pluginName, code: 'MISSING_ENGINE_DEPENDENCIES', message: 'Python sidecar cần engine/requirements.txt.' });
    }
  }

  for (const file of getFilesRecursively(dirPath).filter((item) => /\.(?:js|ts|py)$/.test(item.relPath))) {
    const source = fs.readFileSync(file.fullPath, 'utf8');
    if (file.relPath.endsWith('.js') && !file.relPath.endsWith('sdk.js') && source.includes('window.chrome.webview.postMessage')) {
      errors.push({ plugin: pluginName, code: 'DIRECT_WEBVIEW_BRIDGE', message: `${file.relPath} gọi WebView bridge trực tiếp; dùng window.HocLuc.` });
    }
    if (FIXED_PORT_PATTERN.test(source)) {
      errors.push({ plugin: pluginName, code: 'FIXED_PORT_IN_UI', message: `${file.relPath} có thể chứa cổng sidecar cố định.` });
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
  if (!sourceOnly && !fs.existsSync(hlepPath)) {
    errors.push({
      plugin: pluginName,
      code: 'MISSING_HLEP',
      message: `Gói nén ${pluginName}.hlep chưa tồn tại!`,
      fix: `node scripts/package_plugin.mjs ${pluginName}`,
    });
    outOfSyncPlugins.add(pluginName);
  } else if (!sourceOnly) {
    const files = getFilesRecursively(dirPath);
    let isOutOfSync = false;
    let mismatchPath = null;
    try {
      const archiveFiles = readStoredZipEntries(hlepPath);
      const sourceFiles = new Map(files.map((file) => [file.relPath, fs.readFileSync(file.fullPath)]));
      if (archiveFiles.size !== sourceFiles.size) isOutOfSync = true;
      for (const [name, sourceRaw] of sourceFiles) {
        const packagedRaw = archiveFiles.get(name);
        if (!packagedRaw) {
          isOutOfSync = true;
          mismatchPath = name;
          break;
        }
        const sourceNorm = normalizeEntryBytes(sourceRaw, name);
        const packagedNorm = normalizeEntryBytes(packagedRaw, name);
        if (!sourceNorm.equals(packagedNorm)) {
          isOutOfSync = true;
          mismatchPath = name;
          break;
        }
      }
      if (!mismatchPath && archiveFiles.size !== sourceFiles.size) mismatchPath = 'archive file list';
    } catch (error) {
      isOutOfSync = true;
      mismatchPath = error.message;
    }
    if (isOutOfSync) {
      errors.push({
        plugin: pluginName,
        code: 'OUT_OF_SYNC_HLEP',
        message: `Mã nguồn plugin "${pluginName}" đã bị sửa đổi (ví dụ: ${mismatchPath}) nhưng file "${pluginName}.hlep" chưa được đóng gói lại!`,
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
  console.log(sourceOnly
    ? '🔍 [Plugin Validator] Đang kiểm tra source plugin, bỏ qua freshness của archive...'
    : '🔍 [Plugin Validator] Đang quét toàn bộ plugins và kiểm tra tính toàn vẹn...');
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

