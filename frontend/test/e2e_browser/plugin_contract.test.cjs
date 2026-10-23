const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '../../..');
const readPlugin = (name) => {
  const root = path.join(repoRoot, 'plugins', name);
  return {
    root,
    manifest: JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8')),
  };
};

test('Smart Pen is declared as an installable Schema v2.1 plugin tool', () => {
  const { manifest, root } = readPlugin('smart_pen');
  assert.equal(manifest.$schema, 'https://hocluc.edu.vn/schemas/plugin-manifest-v2.1.json');
  assert.equal(manifest.ui.inject_sdk, true);
  assert.ok(manifest.contributes.tools.some((tool) => tool.pdf_tap_mode === true));
  assert.ok(fs.existsSync(path.join(root, manifest.ui.entry)));
  assert.ok(manifest.permissions.includes('storage'));
  assert.ok(manifest.permissions.includes('board:publish_pdf_regions'));
});

test('plugin UI source uses the SDK and does not call WebView bridge directly', () => {
  for (const name of ['english_assistant', 'smart_pen']) {
    const { root } = readPlugin(name);
    const source = fs.readFileSync(path.join(root, 'ui/app.js'), 'utf8');
    assert.doesNotMatch(source, /window\.chrome\.webview\.postMessage/);
  }
  const smartPenApp = fs.readFileSync(path.join(repoRoot, 'plugins/smart_pen/ui/app.js'), 'utf8');
  assert.match(smartPenApp, /HocLuc\.board\.setTool/);
  assert.match(smartPenApp, /onHostEvent\('board:tool_state'/);
  assert.match(smartPenApp, /HocLuc\?\.onHostEvent\('board:pdf_text_fragments'/);
  assert.doesNotMatch(smartPenApp, /if\s*\(!enabled\s*\|\|/);
  const sdk = fs.readFileSync(path.join(repoRoot, 'frontend/assets/scripts/hocluc-plugin-sdk.js'), 'utf8');
  assert.match(sdk, /onHostEvent: function/);
  assert.match(sdk, /publishPdfRegions: function/);
  assert.match(sdk, /togglePdfAnnotation: function/);
});

test('English Assistant bundled SDK stays in parity with the canonical host SDK', () => {
  const canonicalSdk = fs.readFileSync(
    path.join(repoRoot, 'frontend/assets/scripts/hocluc-plugin-sdk.js'),
    'utf8',
  );
  const bundledSdk = fs.readFileSync(
    path.join(repoRoot, 'plugins/english_assistant/ui/sdk.js'),
    'utf8',
  );

  assert.equal(bundledSdk, canonicalSdk);
});

test('English Assistant opts into transparent WebView while a glass result is visible', () => {
  const { root, manifest } = readPlugin('english_assistant');
  assert.equal(manifest.ui.transparent_background, true);

  const app = fs.readFileSync(path.join(root, 'ui/app.js'), 'utf8');
  const css = fs.readFileSync(path.join(root, 'ui/style.css'), 'utf8');
  assert.match(app, /glass-region-active/);
  assert.match(css, /data-hocluc-transparent-background=['"]true['"]\]\s*body\.glass-region-active/);
  assert.match(css, /body\s*\{[^}]*background-color:\s*var\(--bg-color\)/s);
});

test('SDK dispatches host events to plugin subscribers', () => {
  const sdkPath = path.join(repoRoot, 'frontend/assets/scripts/hocluc-plugin-sdk.js');
  delete require.cache[require.resolve(sdkPath)];
  const sdk = require(sdkPath);
  let received;
  const unsubscribe = sdk.onHostEvent('board:pdf_text_fragments', (payload) => {
    received = payload;
  });

  sdk.__dispatchHostEvent({
    event: 'board:pdf_text_fragments',
    payload: { page_number: 3 },
  });
  assert.deepEqual(received, { page_number: 3 });

  unsubscribe();
  received = undefined;
  sdk.__dispatchHostEvent({
    event: 'board:pdf_text_fragments',
    payload: { page_number: 4 },
  });
  assert.equal(received, undefined);
});

test('Smart Pen package classifies grouped answer markers and rejects isolated prose markers', () => {
  const enginePath = path.join(repoRoot, 'plugins/smart_pen/ui/engine.js');
  delete require.cache[require.resolve(enginePath)];
  const engine = require(enginePath);
  const verticalOptions = ['A.', 'B.', 'C.', 'D.'].map((text, index) => ({
    text,
    bounds: { x: 40, y: 100 + index * 30, width: 14, height: 14 },
  }));
  const page = {
    page_number: 2,
    page_size: { width: 612, height: 792 },
    fragments: verticalOptions,
  };

  assert.deepEqual(engine.classifyPage(page).map((region) => region.label), ['A', 'B', 'C', 'D']);
  assert.equal(engine.classifyPage({
    ...page,
    fragments: [{ text: 'The answer is A.', bounds: { x: 80, y: 100, width: 80, height: 14 } }],
  }).length, 0);
});

test('Smart Pen keeps both columns of a question in one selection group', () => {
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const regions = engine.classifyPage({
    page_number: 1,
    page_size: { width: 612, height: 792 },
    fragments: [
      ['A', 40, 100], ['B', 400, 100],
      ['C', 40, 122], ['D', 400, 122],
    ].map(([label, x, y]) => ({
      text: `${label}.`, bounds: { x, y, width: 14, height: 14 },
    })),
  });

  assert.deepEqual(regions.map((region) => region.label), ['A', 'B', 'C', 'D']);
  assert.equal(new Set(regions.map((region) => region.group_id)).size, 1);
  assert.equal(new Set(regions.map((region) => region.id)).size, 4);
});

test('Smart Pen uses Host question groups and retains distinct option tap regions', () => {
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const regions = engine.classifyPage({
    page_number: 7,
    page_size: { width: 612, height: 792 },
    // The Host has already applied the legacy question classifier.
    answer_candidates: ['A', 'B', 'C', 'D'].map((label, index) => ({
      label,
      group_id: 'question-7',
      bounds: { x: 40 + index * 160, y: 300, width: 12, height: 14 },
    })),
  });

  assert.equal(new Set(regions.map((region) => region.group_id)).size, 1);
  assert.equal(new Set(regions.map((region) => region.id)).size, 4);
  assert.deepEqual(regions.map(({ bounds }) => bounds.x), [40, 200, 360, 520]);
});

test('Smart Pen keeps mixed single-column, two-column, and inline questions separate by question', () => {
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const fragments = [
    // Question 2: vertical list.
    ['A', 40, 100], ['B', 40, 122], ['C', 40, 144], ['D', 40, 166],
    // Question 3: two columns, A/C and B/D.
    ['A', 40, 220], ['B', 330, 220], ['C', 40, 242], ['D', 330, 242],
    // Questions 4 and 5: inline rows.
    ['A', 40, 290], ['B', 150, 290], ['C', 260, 290], ['D', 370, 290],
    ['A', 40, 334], ['B', 150, 334], ['C', 260, 334], ['D', 370, 334],
  ].map(([label, x, y]) => ({
    text: `${label}.`, bounds: { x, y, width: 14, height: 14 },
  }));
  const regions = engine.classifyPage({
    page_number: 1,
    page_size: { width: 612, height: 792 },
    fragments,
  });
  const groups = new Map();
  for (const region of regions) {
    groups.set(region.group_id, [...(groups.get(region.group_id) || []), region.label]);
  }

  assert.deepEqual([...groups.values()], [
    ['A', 'B', 'C', 'D'],
    ['A', 'B', 'C', 'D'],
    ['A', 'B', 'C', 'D'],
    ['A', 'B', 'C', 'D'],
  ]);
  assert.equal(new Set(regions.map((region) => region.id)).size, 16);
});

test('Smart Pen does not pair answer columns beyond eighty percent of page width', () => {
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const regions = engine.classifyPage({
    page_number: 1,
    page_size: { width: 612, height: 792 },
    fragments: [
      ['A', 40, 100], ['C', 40, 122],
      ['B', 535, 108], ['D', 535, 130],
    ].map(([label, x, y]) => ({
      text: `${label}.`, bounds: { x, y, width: 14, height: 14 },
    })),
  });

  assert.equal(regions.length, 4);
  assert.equal(new Set(regions.map((region) => region.group_id)).size, 2);
  const groupsByLabel = new Map(regions.map((region) => [region.label, region.group_id]));
  assert.equal(groupsByLabel.get('A'), groupsByLabel.get('C'));
  assert.equal(groupsByLabel.get('B'), groupsByLabel.get('D'));
  assert.notEqual(groupsByLabel.get('A'), groupsByLabel.get('B'));
});

test('Smart Pen groups partial inline rows and keeps side-by-side questions apart', () => {
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const partial = engine.classifyPage({
    page_number: 1,
    page_size: { width: 612, height: 792 },
    fragments: ['A', 'B', 'C'].map((label, index) => ({
      text: `${label}.`, bounds: { x: 40 + index * 90, y: 100, width: 14, height: 14 },
    })),
  });
  assert.equal(new Set(partial.map((region) => region.group_id)).size, 1);

  const sideBySide = engine.classifyPage({
    page_number: 1,
    page_size: { width: 612, height: 792 },
    fragments: [
      ['A', 40, 100], ['B', 110, 100], ['A', 380, 100], ['B', 450, 100],
      ['C', 40, 122], ['D', 110, 122], ['C', 380, 122], ['D', 450, 122],
    ].map(([label, x, y]) => ({
      text: `${label}.`, bounds: { x, y, width: 14, height: 14 },
    })),
  });
  assert.equal(new Set(sideBySide.map((region) => region.group_id)).size, 2);
});

test('Smart Pen separates nearby questions when OCR misses repeated labels', () => {
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const page = {
    page_number: 1,
    page_size: { width: 612, height: 792 },
    fragments: [['A', 100], ['C', 122], ['B', 154], ['D', 176]].map(
      ([label, y]) => ({
        text: `${label}.`, bounds: { x: 40, y, width: 14, height: 14 },
      }),
    ),
  };
  const regions = engine.classifyPage(page);

  assert.deepEqual(regions.map((region) => region.label), ['A', 'C', 'B', 'D']);
  assert.notEqual(regions[0].group_id, regions[2].group_id);
});

test('Smart Pen retains a lone interior OCR marker as a tappable region', () => {
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const page = {
    page_number: 1,
    page_size: { width: 612, height: 792 },
    fragments: [{ text: 'C.', bounds: { x: 40, y: 300, width: 14, height: 14 } }],
  };
  const regions = engine.classifyPage(page);

  assert.equal(regions.length, 1);
  assert.equal(engine.linkAdjacentPages([{ ...page, regions }])[0].regions.length, 1);
});

test('Smart Pen answer loops hug the marker, look hand-drawn, and scale with the PDF page', () => {
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const pageSize = { width: 612, height: 792 };
  const [region] = engine.classifyPage({
    page_number: 1,
    page_size: pageSize,
    fragments: ['A.', 'B.'].map((text, index) => ({
      text,
      bounds: { x: 80, y: 100 + index * 24, width: 14, height: 14 },
    })),
  });

  assert.ok(region.bounds.width < 19);
  assert.ok(region.bounds.height < 19);
  assert.ok(region.bounds.x > 77);
  assert.equal(region.bounds.width, region.bounds.height);

  const stroke = engine.createAnnotation(region, pageSize);
  assert.equal(stroke.width, 1.5);
  assert.equal(stroke.color, 0xffd93636);
  const pagePoints = stroke.points.map(([x, y]) => [x * pageSize.width, y * pageSize.height]);
  const centerX = (Math.min(...pagePoints.map(([x]) => x)) + Math.max(...pagePoints.map(([x]) => x))) / 2;
  const centerY = (Math.min(...pagePoints.map(([, y]) => y)) + Math.max(...pagePoints.map(([, y]) => y))) / 2;
  const radii = pagePoints.map(([x, y]) => Math.hypot(x - centerX, y - centerY));
  assert.ok(Math.max(...radii) - Math.min(...radii) > 0.2);
  assert.ok(Math.max(...radii) - Math.min(...radii) < 1.5);

  const scaled = {
    ...region,
    bounds: Object.fromEntries(Object.entries(region.bounds).map(([key, value]) => [key, value * 2])),
  };
  const zoomedStroke = engine.createAnnotation(scaled, { width: 1224, height: 1584 });
  assert.deepEqual(zoomedStroke.points, stroke.points);
});

test('Smart Pen links complementary answer groups at adjacent page edges', () => {
  const enginePath = path.join(repoRoot, 'plugins/smart_pen/ui/engine.js');
  delete require.cache[require.resolve(enginePath)];
  const engine = require(enginePath);
  const page = (pageNumber, labels, startY) => {
    const payload = {
      page_number: pageNumber,
      document_generation: 1,
      page_size: { width: 612, height: 792 },
      fragments: labels.map((label, index) => ({
        text: `${label}.`,
        bounds: { x: 40, y: startY + index * 22, width: 12, height: 12 },
      })),
    };
    return { ...payload, regions: engine.classifyPage(payload) };
  };
  const [lower, upper] = engine.linkAdjacentPages([
    page(1, ['A', 'B'], 738),
    page(2, ['C', 'D'], 20),
  ]);

  assert.equal(lower.regions.length, 2);
  assert.equal(upper.regions.length, 2);
  assert.equal(lower.regions[0].group_id, upper.regions[0].group_id);
  const repeated = engine.linkAdjacentPages([lower, upper]);
  assert.equal(repeated[0].regions[0].group_id, lower.regions[0].group_id);
  assert.equal(repeated[1].regions[0].group_id, upper.regions[0].group_id);
});

test('Smart Pen keeps a single edge option until its neighboring page arrives', () => {
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const source = (number, labels, y) => {
    const page = {
      page_number: number, page_size: { width: 612, height: 792 },
      fragments: labels.map((label, index) => ({
        text: `${label}.`, bounds: { x: 40, y: y + index * 20, width: 12, height: 12 },
      })),
    };
    return { ...page, regions: engine.classifyPage(page) };
  };
  const bottom = source(1, ['A', 'B', 'C'], 730);
  const top = source(2, ['D'], 20);
  assert.equal(engine.linkAdjacentPages([top])[0].regions.length, 0);
  const [first, second] = engine.linkAdjacentPages([bottom, top]);
  assert.equal(first.regions.length, 3);
  assert.equal(second.regions.length, 1);
  assert.equal(first.regions[0].group_id, second.regions[0].group_id);
  const stroke = engine.createAnnotation(second.regions[0], second.page_size);
  assert.ok(stroke.points.length >= 3);
  assert.ok(stroke.points.every((point) => point.every((value) => value >= 0 && value <= 1)));
});

test('host activation reaches the plugin and sends plugin-owned geometry', async () => {
  const vm = require('node:vm');
  const handlers = new Map();
  const elements = { toggle: { addEventListener() {} }, status: {} };
  const published = [];
  const toggled = [];
  const migrated = [];
  const engine = require(path.join(repoRoot, 'plugins/smart_pen/ui/engine.js'));
  const context = vm.createContext({
    document: { getElementById: (id) => elements[id] },
    window: {
      HocLucSmartPenEngine: engine,
      HocLuc: {
        getContext: async () => ({ activeTool: null }),
        onHostEvent: (name, handler) => handlers.set(name, handler),
        board: {
          publishPdfRegions: async (...args) => published.push(args),
          togglePdfAnnotation: async (...args) => toggled.push(args),
          rekeyPdfAnnotationGroup: async (...args) => migrated.push(args),
        },
      },
    },
  });
  vm.runInContext(fs.readFileSync(path.join(repoRoot, 'plugins/smart_pen/ui/app.js'), 'utf8'), context);
  await Promise.resolve();
  handlers.get('board:tool_state')({ active_tool: 'answer_marker' });
  assert.match(elements.toggle.textContent, /./);
  await handlers.get('board:pdf_text_fragments')({
    page_number: 1, document_generation: 5, page_size: { width: 612, height: 792 },
    answer_candidates: ['A', 'B', 'C', 'D'].map((label, index) => ({
      label,
      group_id: 'host-question-1',
      bounds: { x: 40, y: 100 + index * 17, width: 12, height: 12 },
    })),
  });
  assert.equal(published.length, 1);
  await handlers.get('board:pdf_tap')({
    page_number: 1, document_generation: 5, page_point: { x: 46, y: 123 },
    hit_tolerance: 10,
  });
  assert.equal(toggled.length, 1);
  assert.equal(toggled[0][3].label, 'B');
  assert.equal(toggled[0][5].stroke.color, 0xffd93636);
  assert.ok(toggled[0][5].stroke.points.length >= 3);
  await handlers.get('board:pdf_tap')({
    page_number: 1, document_generation: 5, page_point: { x: 46, y: 140 },
    hit_tolerance: 10,
  });
  assert.equal(toggled.at(-1)[3].label, 'C');
  assert.equal(toggled[0][3].group_id, toggled.at(-1)[3].group_id);
  assert.notEqual(toggled[0][3].id, toggled.at(-1)[3].id);

  const edgePage = (number, labels, y) => ({
    page_number: number, document_generation: 6,
    page_size: { width: 612, height: 792 },
    fragments: labels.map((label, index) => ({
      text: `${label}.`, bounds: { x: 40, y: y + index * 20, width: 12, height: 12 },
    })),
  });
  await handlers.get('board:pdf_text_fragments')(edgePage(2, ['C', 'D'], 20));
  await handlers.get('board:pdf_tap')({
    page_number: 2, document_generation: 6, page_point: { x: 44, y: 26 },
  });
  const oldGroup = toggled.at(-1)[3].group_id;
  await handlers.get('board:pdf_text_fragments')(edgePage(1, ['A', 'B'], 738));
  assert.equal(migrated.length, 1);
  assert.equal(migrated[0][1], oldGroup);
  assert.notEqual(migrated[0][2], oldGroup);
  await handlers.get('board:pdf_tap')({
    page_number: 1, document_generation: 6, page_point: { x: 44, y: 744 },
  });
  assert.equal(toggled.at(-1)[3].group_id, migrated[0][2]);
});
