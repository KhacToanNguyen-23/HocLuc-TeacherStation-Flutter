const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..', '..', '..', '..');
const pluginDir = path.join(root, 'plugins', 'english_assistant');

function filesUnder(directory, extension) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === '__pycache__' || entry.name === '.dart_tool') return [];
      return filesUnder(fullPath, extension);
    }
    return fullPath.endsWith(extension) ? [fullPath] : [];
  });
}

test('English Assistant declares the plugin-owned Dart binary sidecar', () => {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(pluginDir, 'manifest.json'), 'utf8'),
  );
  assert.equal(manifest.backend.type, 'binary');
  assert.equal(manifest.backend.entry, 'engine/bin/english_assistant_engine.exe');
  assert.equal(
    manifest.backend.development_entry,
    'engine/dart/bin/english_assistant_engine.dart',
  );
  assert.equal(manifest.backend.health_endpoint, '/health');
  for (const staleRuntime of ['service.py', 'dgnl_analyzer.py', 'grammar_rules.py']) {
    assert.equal(
      fs.existsSync(path.join(pluginDir, 'engine', staleRuntime)),
      false,
      `${staleRuntime} remains in the plugin runtime`,
    );
  }
});

test('no plugin Python source, spaCy runtime, or Cloze implementation remains', () => {
  const pythonSources = filesUnder(path.join(pluginDir, 'engine'), '.py');
  assert.deepEqual(
    pythonSources,
    [],
    'the migrated plugin source tree must not contain Python files',
  );
  const forbidden = pythonSources
    .filter((file) => /spacy|cloze/i.test(fs.readFileSync(file, 'utf8')))
    .map((file) => path.relative(pluginDir, file));
  assert.deepEqual(forbidden, []);
});

test('English Assistant has no OCR implementation, tests, or model assets', () => {
  const removedOcrFiles = [
    'engine/ocr_recovery.py',
    'engine/tests/test_ocr_recovery.py',
    'engine/dart/lib/src/ocr_recovery.dart',
    'engine/dart/test/ocr_recovery_test.dart',
    'engine/models/en_PP-OCRv3_rec_infer.onnx',
    'engine/models/en_PP-OCRv4_rec_infer.onnx',
    'engine/models/en_dict.txt',
    'engine/models/english_vocab.txt',
  ];
  for (const relativePath of removedOcrFiles) {
    assert.equal(
      fs.existsSync(path.join(pluginDir, relativePath)),
      false,
      `${relativePath} remains after OCR removal`,
    );
  }

  const entryPoint = fs.readFileSync(
    path.join(pluginDir, 'engine', 'dart', 'lib', 'english_assistant_engine.dart'),
    'utf8',
  );
  assert.doesNotMatch(entryPoint, /ocr_recovery/);
});

test('collocation datasets contain no Cloze-only answer or distractor fields', () => {
  const entries = JSON.parse(
    fs.readFileSync(path.join(pluginDir, 'engine', 'data', 'academic_collocations.json'), 'utf8'),
  );
  for (const entry of entries) {
    for (const field of ['target_word', 'mask_type', 'distractors']) {
      assert.equal(Object.hasOwn(entry, field), false, `${field} remains in ${entry.phrase}`);
    }
  }
});

test('Core no longer contains a Cloze workflow for passage analysis', () => {
  const coreDart = filesUnder(
    path.join(root, 'frontend', 'lib', 'features', 'studio_board'),
    '.dart',
  )
    .map((file) => fs.readFileSync(file, 'utf8'))
    .join('\n');
  assert.doesNotMatch(
    coreDart,
    /generateCloze|fallbackGenerateCloze|clozeQuestions|_showClozeModal|generate-cloze|Cloze Test/i,
  );
});

test('English Assistant only contributes passage scanning, not manual text input', () => {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(pluginDir, 'manifest.json'), 'utf8'),
  );
  assert.deepEqual(
    manifest.contributes.tools.map((tool) => tool.id),
    ['snip_passage'],
  );
});

test('PDF regions without a text layer explain that scanning is unavailable', () => {
  const snippingOverlay = fs.readFileSync(
    path.join(
      root,
      'frontend',
      'lib',
      'features',
      'studio_board',
      'presentation',
      'region_snipping_overlay.dart',
    ),
    'utf8',
  );
  assert.match(snippingOverlay, /Vùng chọn không có lớp văn bản/);
  assert.match(
    snippingOverlay,
    /Vùng chọn không có lớp văn bản nên không thể quét nội dung này/,
  );
  assert.doesNotMatch(snippingOverlay, /Nhập văn bản|manual text input/);
});
