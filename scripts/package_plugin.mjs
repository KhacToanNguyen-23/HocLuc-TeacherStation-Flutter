import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ensureHooksConfigured } from './setup_hooks.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

// Tự động đảm bảo Git hook được cấu hình ngầm khi dev chạy lệnh đóng gói
ensureHooksConfigured(true);

const targetArg = process.argv[2] || 'casio_calculator';
const targetPluginName = path.basename(targetArg);
const pluginDir = path.isAbsolute(targetArg) ? targetArg : path.join(rootDir, 'plugins', targetPluginName);
const outputHlep = path.join(rootDir, 'plugins', `${targetPluginName}.hlep`);

console.log(`Packaging plugin from: ${pluginDir}`);
console.log(`Target archive: ${outputHlep}`);

function validateManifest(sourceDir) {
  const manifestPath = path.join(sourceDir, 'manifest.json');
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Missing manifest.json in ${sourceDir}`);
  }
  const raw = fs.readFileSync(manifestPath, 'utf8');
  const manifest = JSON.parse(raw);
  for (const field of ['id', 'name', 'version']) {
    if (!manifest[field] || typeof manifest[field] !== 'string') {
      throw new Error(`Invalid manifest.json: missing required string field "${field}"`);
    }
  }
  console.log(`Validated manifest.json: ${manifest.id} v${manifest.version} (${manifest.name})`);
}

// Minimal zip creator without external dependencies
function createZip(sourceDir, outputFile) {
  validateManifest(sourceDir);

  // Ensure icon.png exists if not present
  const iconPath = path.join(sourceDir, 'icon.png');
  if (!fs.existsSync(iconPath)) {
    // 1x1 transparent png
    const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    fs.writeFileSync(iconPath, Buffer.from(pngBase64, 'base64'));
  }

  const files = [];
  function collectFiles(dir, relative = '') {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      const relPath = path.join(relative, entry.name).replace(/\\/g, '/');
      if (entry.isDirectory()) {
        if (entry.name === '__pycache__' || entry.name === '.venv' || entry.name === 'node_modules') {
          continue;
        }
        if (relPath === 'engine/tests' || relPath.startsWith('engine/tests/') ||
            relPath === 'engine/benchmarks' || relPath.startsWith('engine/benchmarks/')) {
          continue;
        }
        collectFiles(fullPath, relPath);
      } else {
        files.push({ relPath, data: fs.readFileSync(fullPath) });
      }
    }
  }

  collectFiles(sourceDir);

  const localHeaders = [];
  const centralHeaders = [];
  let offset = 0;

  for (const file of files) {
    const nameBuffer = Buffer.from(file.relPath, 'utf8');
    const dataBuffer = file.data;
    const crc = crc32(dataBuffer);

    // Local file header (30 bytes + filename)
    const localHeader = Buffer.alloc(30 + nameBuffer.length);
    localHeader.writeUInt32LE(0x04034b50, 0); // Signature
    localHeader.writeUInt16LE(20, 4);          // Version needed
    localHeader.writeUInt16LE(0, 6);           // Flags
    localHeader.writeUInt16LE(0, 8);           // Compression: 0 = Store
    localHeader.writeUInt16LE(0, 10);          // Mod time
    localHeader.writeUInt16LE(0, 12);          // Mod date
    localHeader.writeUInt32LE(crc, 14);        // CRC-32
    localHeader.writeUInt32LE(dataBuffer.length, 18); // Compressed size
    localHeader.writeUInt32LE(dataBuffer.length, 22); // Uncompressed size
    localHeader.writeUInt16LE(nameBuffer.length, 26); // Filename length
    localHeader.writeUInt16LE(0, 28);                 // Extra field length
    nameBuffer.copy(localHeader, 30);

    // Central directory header (46 bytes + filename)
    const centralHeader = Buffer.alloc(46 + nameBuffer.length);
    centralHeader.writeUInt32LE(0x02014b50, 0); // Signature
    centralHeader.writeUInt16LE(20, 4);          // Version made by
    centralHeader.writeUInt16LE(20, 6);          // Version needed
    centralHeader.writeUInt16LE(0, 8);           // Flags
    centralHeader.writeUInt16LE(0, 10);          // Compression
    centralHeader.writeUInt16LE(0, 12);          // Mod time
    centralHeader.writeUInt16LE(0, 14);          // Mod date
    centralHeader.writeUInt32LE(crc, 16);        // CRC-32
    centralHeader.writeUInt32LE(dataBuffer.length, 20);
    centralHeader.writeUInt32LE(dataBuffer.length, 24);
    centralHeader.writeUInt16LE(nameBuffer.length, 28);
    centralHeader.writeUInt16LE(0, 30);          // Extra field length
    centralHeader.writeUInt16LE(0, 32);          // Comment length
    centralHeader.writeUInt16LE(0, 34);          // Disk start
    centralHeader.writeUInt16LE(0, 36);          // Internal attributes
    centralHeader.writeUInt32LE(0, 38);          // External attributes
    centralHeader.writeUInt32LE(offset, 42);     // Relative offset of local header
    nameBuffer.copy(centralHeader, 46);

    localHeaders.push(localHeader, dataBuffer);
    centralHeaders.push(centralHeader);

    offset += localHeader.length + dataBuffer.length;
  }

  const centralDirOffset = offset;
  let centralDirSize = 0;
  for (const ch of centralHeaders) centralDirSize += ch.length;

  // End of central directory record (22 bytes)
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0); // Signature
  eocd.writeUInt16LE(0, 4);          // Disk number
  eocd.writeUInt16LE(0, 6);          // Start disk
  eocd.writeUInt16LE(files.length, 8);
  eocd.writeUInt16LE(files.length, 10);
  eocd.writeUInt32LE(centralDirSize, 12);
  eocd.writeUInt32LE(centralDirOffset, 16);
  eocd.writeUInt16LE(0, 20);         // Comment length

  const fullBuffer = Buffer.concat([...localHeaders, ...centralHeaders, eocd]);
  fs.writeFileSync(outputFile, fullBuffer);
  const sha256 = crypto.createHash('sha256').update(fullBuffer).digest('hex');
  console.log(`Successfully created ${outputFile} (${fullBuffer.length} bytes, ${files.length} files, sha256: ${sha256})`);
}

// CRC32 table & function
const crcTable = new Uint32Array(256);
for (let i = 0; i < 256; i++) {
  let c = i;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  crcTable[i] = c;
}

function crc32(buf) {
  let crc = 0 ^ (-1);
  for (let i = 0; i < buf.length; i++) {
    crc = (crc >>> 8) ^ crcTable[(crc ^ buf[i]) & 0xff];
  }
  return (crc ^ (-1)) >>> 0;
}

createZip(pluginDir, outputHlep);
