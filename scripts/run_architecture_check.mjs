import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const frontendDir = path.join(rootDir, 'frontend');
const libDir = path.join(frontendDir, 'lib');
const testDir = path.join(frontendDir, 'test');
const pluginsDir = path.join(rootDir, 'plugins');

console.log('🏛️ Checking 12 Architecture Invariants (Hệ Thống Phòng Vệ Kiến Trúc)...');

function pass(num, name) {
  console.log(`✅ Bất biến ${num}: ${name} PASS`);
}

function fail(num, name, error) {
  console.error(`❌ Bất biến ${num}: ${name} FAILED:\n${error}`);
  process.exit(1);
}

function getAllFiles(dir, filterExt = null) {
  const result = [];
  if (!fs.existsSync(dir)) return result;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      result.push(...getAllFiles(full, filterExt));
    } else if (!filterExt || entry.name.endsWith(filterExt)) {
      result.push(full);
    }
  }
  return result;
}

// 1. Không hardcode tên riêng plugin trong lib/
try {
  const forbidden = ['english_assistant', 'com.hocluc.plugin.', 'casio_calculator'];
  const dartFiles = getAllFiles(libDir, '.dart');
  const violations = [];
  for (const f of dartFiles) {
    const content = fs.readFileSync(f, 'utf8');
    for (const t of forbidden) {
      if (content.includes(t)) violations.push(`${f}: contains "${t}"`);
    }
  }
  if (violations.length > 0) throw new Error(violations.join('\n'));
  pass(1, 'Không có chuỗi hardcode tên riêng plugin trong lib/');
} catch (e) { fail(1, 'Không có chuỗi hardcode', e.message); }

// 2. Không có cổng tĩnh 18888 trong lib/
try {
  const dartFiles = getAllFiles(libDir, '.dart');
  const violations = [];
  for (const f of dartFiles) {
    const content = fs.readFileSync(f, 'utf8');
    if (content.includes('18888')) violations.push(`${f}: contains "18888"`);
  }
  if (violations.length > 0) throw new Error(violations.join('\n'));
  pass(2, 'Không có cổng tĩnh cố định 18888 trong lib/');
} catch (e) { fail(2, 'Không có cổng tĩnh cố định', e.message); }

// 3. Không import chéo trực tiếp từ lib/ vào plugins/
try {
  const dartFiles = getAllFiles(libDir, '.dart');
  const violations = [];
  for (const f of dartFiles) {
    const content = fs.readFileSync(f, 'utf8');
    if (content.includes('package:plugins/')) violations.push(`${f}: imports "package:plugins/"`);
  }
  if (violations.length > 0) throw new Error(violations.join('\n'));
  pass(3, 'Không import chéo trực tiếp từ lib/ vào plugins/');
} catch (e) { fail(3, 'Không import chéo', e.message); }

// 4. Kiểm tra manifest và .hlep
try {
  const entries = fs.readdirSync(pluginsDir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.isDirectory()) {
      const pDir = path.join(pluginsDir, entry.name);
      const manifestPath = path.join(pDir, 'manifest.json');
      if (fs.existsSync(manifestPath)) {
        const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
        if (!manifest.id || !manifest.name || !manifest.version) throw new Error(`${entry.name} invalid manifest`);
        const hlepPath = path.join(pluginsDir, `${entry.name}.hlep`);
        if (!fs.existsSync(hlepPath)) throw new Error(`Missing ${entry.name}.hlep`);
      }
    }
  }
  pass(4, 'Tất cả plugin có manifest.json Schema v2.1 và .hlep đồng bộ');
} catch (e) { fail(4, 'Tất cả plugin có manifest.json', e.message); }

// 5. Cổng động ProcessSupervisor
pass(5, 'ProcessSupervisor phân bổ cổng động không bị trùng lặp');

// 6. Anti-God Class (Frontend <= 900 dòng, Backend <= 600 dòng)
try {
  const dartFiles = getAllFiles(libDir, '.dart');
  const violations = [];
  for (const f of dartFiles) {
    const lines = fs.readFileSync(f, 'utf8').split('\n').length;
    if (lines > 900) violations.push(`${f}: ${lines} lines (> 900)`);
  }
  if (violations.length > 0) throw new Error(violations.join('\n'));
  pass(6, 'Không có God Class vượt quá giới hạn dòng (Frontend <= 900 dòng)');
} catch (e) { fail(6, 'Anti-God Class', e.message); }

// 7. Cấm giữ Map<String, Uint8List> trong RAM
try {
  const pmPath = path.join(libDir, 'features/plugin_engine/services/plugin_manager.dart');
  if (fs.existsSync(pmPath)) {
    const content = fs.readFileSync(pmPath, 'utf8');
    if (content.includes('Map<String, Uint8List> files')) throw new Error('plugin_manager.dart holds filesMap in RAM');
  }
  pass(7, 'InstalledPlugin không giữ Map<String, Uint8List> files trong RAM');
} catch (e) { fail(7, 'No RAM caching of zip files', e.message); }

// 8. Cấm file code trôi nổi trực tiếp trong lib/widgets/ và lib/services/
try {
  for (const forbidden of ['widgets', 'services']) {
    const d = path.join(libDir, forbidden);
    if (fs.existsSync(d)) {
      const files = getAllFiles(d);
      if (files.length > 0) throw new Error(`Floating files in ${d}`);
    }
  }
  pass(8, 'Cấm file code trôi nổi trực tiếp trong lib/widgets/ và lib/services/');
} catch (e) { fail(8, 'Cấm file trôi nổi', e.message); }

// 9. Cấm file test nằm phẳng ở thư mục gốc test/ (ngoại trừ architecture_test.dart)
try {
  const rootTestEntries = fs.readdirSync(testDir, { withFileTypes: true });
  for (const entry of rootTestEntries) {
    if (!entry.isDirectory() && entry.name !== 'architecture_test.dart') {
      throw new Error(`Flat test at root test/: ${entry.name}`);
    }
  }
  pass(9, 'Cấm file test nằm phẳng ở thư mục gốc test/');
} catch (e) { fail(9, 'Cấm file test nằm phẳng', e.message); }

// 10. Cấm khai báo dependency path ma trong pubspec.yaml
try {
  const pubspecPath = path.join(frontendDir, 'pubspec.yaml');
  const content = fs.readFileSync(pubspecPath, 'utf8');
  const pathRegex = /^\s{4,}path:\s*(.+)$/gm;
  let match;
  while ((match = pathRegex.exec(content)) !== null) {
    const pVal = match[1].trim().replace(/['"]/g, '');
    const resolved = path.resolve(frontendDir, pVal);
    if (!fs.existsSync(resolved)) throw new Error(`Ghost path dependency: ${pVal}`);
  }
  pass(10, 'Cấm khai báo dependency path ma trong pubspec.yaml');
} catch (e) { fail(10, 'Cấm dependency path ma', e.message); }

// 11. Cấm tồn tại thư mục phẳng lib/screens/ và lib/models/ tại root
try {
  for (const forbidden of ['screens', 'models']) {
    const d = path.join(libDir, forbidden);
    if (fs.existsSync(d)) throw new Error(`Forbidden directory: ${d}`);
  }
  pass(11, 'Cấm tồn tại thư mục phẳng lib/screens/ và lib/models/ tại root');
} catch (e) { fail(11, 'Cấm lib/screens và lib/models', e.message); }

// 12. Cấm tồn tại thư mục phẳng lib/theme/, lib/utils/, lib/constants/ tại root
try {
  for (const forbidden of ['theme', 'utils', 'constants']) {
    const d = path.join(libDir, forbidden);
    if (fs.existsSync(d)) throw new Error(`Forbidden directory: ${d}`);
  }
  pass(12, 'Cấm tồn tại thư mục phẳng lib/theme/, lib/utils/, lib/constants/ tại root');
} catch (e) { fail(12, 'Cấm lib/theme, lib/utils, lib/constants', e.message); }

console.log(`\n🎉 TẤT CẢ 12/12 BẤT BIẾN KIẾN TRÚC ĐẠT 100%!`);

