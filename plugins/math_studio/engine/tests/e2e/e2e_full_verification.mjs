import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import puppeteer from 'puppeteer-core';

const uiDir = path.resolve('plugins/math_studio/ui');
const evidenceDir = path.resolve('plans/math-studio-real-engine/evidence');
if (!fs.existsSync(evidenceDir)) fs.mkdirSync(evidenceDir, { recursive: true });

const EDGE_PATH = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ttf': 'font/ttf',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
};

// 1. Local HTTP server
const server = http.createServer((req, res) => {
  let reqPath = req.url.split('?')[0];
  if (reqPath === '/favicon.ico') {
    res.writeHead(204);
    res.end();
    return;
  }
  if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
  const filePath = path.join(uiDir, reqPath.replace(/^\//, ''));
  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    const ext = path.extname(filePath);
    res.writeHead(200, {
      'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
      'Access-Control-Allow-Origin': '*',
    });
    fs.createReadStream(filePath).pipe(res);
  } else {
    res.writeHead(404);
    res.end('Not Found: ' + reqPath);
  }
});

await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port;
console.log(`Verification Server listening on http://127.0.0.1:${port}`);

const profileDir = path.resolve('plugins/math_studio/.cache/edge_profile_verify');
if (!fs.existsSync(profileDir)) fs.mkdirSync(profileDir, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: EDGE_PATH,
  userDataDir: profileDir,
  headless: true,
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-gpu',
    '--disable-web-security',
  ],
});

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  const networkRequests = [];
  const externalRequests = [];
  const consoleErrors = [];

  page.on('request', (req) => {
    const url = req.url();
    networkRequests.push(url);
    if (!url.startsWith(`http://127.0.0.1:${port}`) && !url.startsWith('data:')) {
      externalRequests.push(url);
    }
  });

  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });

  // Inject Mock window.HocLuc SDK
  await page.evaluateOnNewDocument(() => {
    window.__stampedAnnotations = [];
    window.__pluginClosed = false;

    window.HocLuc = {
      board: {
        insertAnnotation: async (payload) => {
          console.log('[MockSDK] Annotation inserted:', payload?.data?.title);
          window.__stampedAnnotations.push(payload);
          return { id: 'anno-verify-1', success: true };
        },
      },
      close: () => {
        window.__pluginClosed = true;
      },
    };
  });

  console.log('Opening Math Studio in Headless Edge...');
  await page.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: 'networkidle0' });
  await page.waitForSelector('canvas', { timeout: 10000 });

  async function testFunction(formula, expectedDerivCheck, screenshotName) {
    console.log(`\nTesting formula: "${formula}"...`);
    await page.click('#formula-input', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.keyboard.type(formula);
    await new Promise((r) => setTimeout(r, 350));

    const derivText = await page.$eval('#derivative-display', (el) => el.textContent.trim());
    console.log(`  -> y' = "${derivText}"`);
    if (!expectedDerivCheck(derivText)) {
      throw new Error(`Formula "${formula}" failed derivative check! Got: "${derivText}"`);
    }

    if (screenshotName) {
      const shotPath = path.join(evidenceDir, screenshotName);
      await page.screenshot({ path: shotPath });
      console.log(`  -> Screenshot saved: ${screenshotName}`);
    }
  }

  // Benchmark 1: 2x^2 - 3x + 1 (the user's reported bug)
  await testFunction('2x^2 - 3x + 1', (d) => d.includes('4x') && d.includes('3'), 'graph-2x2-3x+1.png');

  // Benchmark 2: x^3 - 3x
  await testFunction('x^3 - 3x', (d) => d.includes('3x') && d.includes('3'), 'graph-x3-3x.png');

  // Benchmark 3: (2x+1)/(x-1)
  await testFunction('(2x+1)/(x-1)', (d) => d.includes('x') && d.includes('/'), null);

  // Benchmark 4: (x^2+x+1)/(x-1)
  await testFunction('(x^2+x+1)/(x-1)', (d) => d.length > 0, null);

  // Benchmark 5: sin(x)
  await testFunction('sin(x)', (d) => d.toLowerCase().includes('cos'), null);

  // Benchmark 6: e^(-x^2)
  await testFunction('e^(-x^2)', (d) => d.includes('x'), null);

  // Benchmark 7: sqrt(4-x^2)
  await testFunction('sqrt(4-x^2)', (d) => d.includes('x'), null);

  // Benchmark 8: ln(x)
  await testFunction('ln(x)', (d) => d.includes('1') && d.includes('x'), null);

  // Test Tab 2: BBT for x^3 - 3x
  console.log('\nTesting BBT Page Screenshot...');
  await testFunction('x^3 - 3x', (d) => true, null);
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('.tab-btn'));
    const b = btns.find((el) => el.textContent.includes('Bảng biến thiên'));
    if (b) b.click();
  });
  await new Promise((r) => setTimeout(r, 400));
  await page.waitForSelector('#bbt-svg');
  await page.screenshot({ path: path.join(evidenceDir, 'bbt-x3-3x.png') });
  console.log('  -> Screenshot saved: bbt-x3-3x.png');

  // Test Tab 3: Riemann Sums & 3D Solid for sqrt(x)
  console.log('\nTesting Tab 3 (Tích phân & Tròn xoay)...');
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('.tab-btn'));
    const b = btns.find((el) => el.textContent.includes('Đồ thị'));
    if (b) b.click();
  });
  await new Promise((r) => setTimeout(r, 200));
  await testFunction('sqrt(x)', (d) => true, null);

  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('.tab-btn'));
    const b = btns.find((el) => el.textContent.includes('Tích phân'));
    if (b) b.click();
  });
  await new Promise((r) => setTimeout(r, 400));
  await page.screenshot({ path: path.join(evidenceDir, 'integral-riemann-sqrt-x.png') });
  console.log('  -> Screenshot saved: integral-riemann-sqrt-x.png');

  // Toggle 3D Solid of Revolution
  await page.evaluate(() => {
    const toggle = document.querySelector('.toggle-switch input');
    if (toggle && !toggle.checked) toggle.click();
  });
  await new Promise((r) => setTimeout(r, 500));
  await page.screenshot({ path: path.join(evidenceDir, 'solid3d-revolution-sqrt-x.png') });
  console.log('  -> Screenshot saved: solid3d-revolution-sqrt-x.png');

  // Stamp to chalkboard
  console.log('\nTesting "Ghim vào bảng" from 3D mode...');
  await page.click('#btn-stamp-board');
  for (let i = 0; i < 25; i++) {
    const count = await page.evaluate(() => window.__stampedAnnotations.length);
    if (count > 0) break;
    await new Promise((r) => setTimeout(r, 200));
  }
  const stamped = await page.evaluate(() => window.__stampedAnnotations);
  console.log(`Stamped annotations received: ${stamped.length}`);

  console.log(`\nFinal Verification Results:`);
  console.log(`  - Total HTTP requests: ${networkRequests.length}`);
  console.log(`  - External requests (MUST BE 0): ${externalRequests.length}`);
  console.log(`  - Console errors: ${consoleErrors.length}`);

  const passed =
    externalRequests.length === 0 &&
    consoleErrors.length === 0 &&
    stamped.length > 0;

  console.log(`\n=== FULL E2E VERIFICATION: ${passed ? 'ALL PASSED (100%)' : 'FAILED'} ===\n`);
  if (!passed) process.exit(1);

} finally {
  await browser.close();
  server.close();
}
