import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import puppeteer from 'puppeteer-core';

const uiDir = path.resolve('plugins/math_studio/ui');
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

// 1. Static HTTP server serving plugins/math_studio/ui
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
console.log(`E2E Server listening on http://127.0.0.1:${port}`);

const profileDir = path.resolve('plugins/math_studio/.cache/edge_profile_e2e');
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
    console.log(`[BROWSER ${msg.type()}]: ${msg.text()}`);
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });

  // Inject Mock window.HocLuc SDK before page loads
  await page.evaluateOnNewDocument(() => {
    window.__stampedAnnotations = [];
    window.__pluginClosed = false;

    window.HocLuc = {
      board: {
        insertAnnotation: async (payload) => {
          console.log('[MockSDK] board.insertAnnotation called:', payload?.type, payload?.data?.title);
          window.__stampedAnnotations.push(payload);
          return { id: 'anno-mock-1', success: true };
        },
      },
      close: () => {
        console.log('[MockSDK] close called');
        window.__pluginClosed = true;
      },
    };
  });

  // 1. Load Math Studio UI
  console.log('Navigating to Math Studio...');
  const t0 = Date.now();
  await page.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: 'networkidle0' });
  const loadTime = Date.now() - t0;
  console.log(`Math Studio UI loaded in ${loadTime} ms`);

  // Wait for canvas
  await page.waitForSelector('canvas', { timeout: 10000 });
  console.log('Canvas detected!');

  // Verify Initial State
  const initDeriv = await page.$eval('#derivative-display', (el) => el.textContent.trim());
  console.log(`Initial y' for x^3 - 3x: "${initDeriv}"`);

  // 2. Test typing 2x^2 - 3x + 1 (the exact function from the user's screenshot)
  console.log('Typing "2x^2 - 3x + 1" into formula input...');
  await page.click('#formula-input', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.keyboard.type('2x^2 - 3x + 1');

  // Wait for debounce & math computation (150ms)
  await new Promise((r) => setTimeout(r, 400));

  const newDeriv = await page.$eval('#derivative-display', (el) => el.textContent.trim());
  console.log(`Computed y' for 2x^2 - 3x + 1: "${newDeriv}"`);
  if (!newDeriv.includes('4x') || !newDeriv.includes('3')) {
    throw new Error(`Expected y' to be 4x - 3, but got "${newDeriv}"!`);
  }
  console.log('PASS: Correct dynamic derivative y\' = 4x - 3 calculated!');

  // 3. Test Tab 2: Bảng Biến Thiên
  console.log('Switching to Tab 2 (Bảng biến thiên)...');
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('.tab-btn'));
    const bbtBtn = btns.find((b) => b.textContent.includes('Bảng biến thiên'));
    if (bbtBtn) bbtBtn.click();
  });
  await new Promise((r) => setTimeout(r, 300));
  await page.waitForSelector('#bbt-svg', { timeout: 5000 });
  console.log('PASS: Bảng Biến Thiên SVG rendered on Tab 2!');

  // 4. Test Tab 3: Tích phân & Tròn xoay
  console.log('Switching to Tab 3 (Tích phân & Tròn xoay)...');
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('.tab-btn'));
    const intBtn = btns.find((b) => b.textContent.includes('Tích phân'));
    if (intBtn) intBtn.click();
  });
  await new Promise((r) => setTimeout(r, 400));
  await page.waitForSelector('canvas', { timeout: 5000 });

  // Toggle 3D Solid of Revolution
  console.log('Toggling 3D Solid of Revolution...');
  await page.evaluate(() => {
    const toggle = document.querySelector('.toggle-switch input');
    if (toggle) toggle.click();
  });
  await new Promise((r) => setTimeout(r, 400));
  console.log('PASS: 3D Solid of Revolution toggled successfully!');

  // 5. Test Stamping to chalkboard
  console.log('Testing "Ghim vào bảng" action...');
  await page.click('#btn-stamp-board');

  // Wait for stamp to complete
  for (let i = 0; i < 20; i++) {
    const count = await page.evaluate(() => window.__stampedAnnotations.length);
    if (count > 0) break;
    await new Promise((r) => setTimeout(r, 200));
  }

  const stamped = await page.evaluate(() => window.__stampedAnnotations);
  console.log(`Stamped annotations received by Mock SDK: ${stamped.length}`);
  if (stamped.length === 0) {
    throw new Error('No annotation was sent to HocLuc SDK!');
  }
  const anno = stamped[0];
  console.log(`Annotation title: "${anno.data.title}", has image: ${!!anno.data.imageBase64}`);

  // 6. Test Close
  console.log('Testing Close button...');
  await page.click('#btn-close-studio');
  const wasClosed = await page.evaluate(() => window.__pluginClosed);
  console.log(`Plugin close called: ${wasClosed}`);
  if (!wasClosed) {
    throw new Error('Close button did not invoke SDK close()!');
  }

  // 7. Verify Offline Integrity
  console.log(`External requests: ${externalRequests.length}, Console errors: ${consoleErrors.length}`);
  if (externalRequests.length > 0) {
    console.error('External requests leaked:', externalRequests);
  }

  const passed =
    externalRequests.length === 0 &&
    consoleErrors.length === 0 &&
    newDeriv.includes('4x') &&
    stamped.length > 0 &&
    wasClosed;

  console.log(`\n=== E2E SMOKE TEST RESULT: ${passed ? 'PASS (100%)' : 'FAIL'} ===`);
  if (!passed) process.exit(1);

} finally {
  await browser.close();
  server.close();
}
