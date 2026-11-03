const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..', '..', '..', '..');
const plugin = path.join(root, 'plugins', 'english_assistant');
const read = (relative) => fs.readFileSync(path.join(plugin, relative), 'utf8');

test('plugin no longer ships a legacy Python analysis service or analyzer', () => {
  for (const file of ['engine/service.py', 'engine/dgnl_analyzer.py']) {
    assert.equal(fs.existsSync(path.join(plugin, file)), false);
  }
});

test('plugin manifest and UI contain no sentence-role tool or screen', () => {
  const manifest = JSON.parse(read('manifest.json'));
  assert.equal(manifest.contributes.tools.some((tool) => tool.id === 'svo'), false);
  assert.doesNotMatch(read('ui/index.html'), /S-V-O|tabContentSvo|tokensContainer|grammarAlert/i);
  assert.doesNotMatch(read('ui/app.js'), /analyze-svo|offlineAnalyze|role-subject|role-verb/i);
});

test('Core contains no sentence-role analyzer or analysis callsites', () => {
  const core = fs.readdirSync(path.join(root, 'frontend', 'lib'), { recursive: true })
    .filter((name) => name.endsWith('.dart'))
    .map((name) => fs.readFileSync(path.join(root, 'frontend', 'lib', name), 'utf8'))
    .join('\n');
  assert.doesNotMatch(core, /EnglishSentenceAnalyzer|analyze-svo|Subject.?Verb.?Object/i);
});
