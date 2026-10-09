// Minimal host of the same Fastboard engine used in service-providers/fastboard.
// Flat's classroom store/RTC/RTM are deliberately not initialized here.
import { createFastboard, createUI } from '@netless/fastboard';
let app;
let ui;
const form = document.querySelector('#join');
const message = document.querySelector('#message');
form.addEventListener('submit', async event => {
  event.preventDefault();
  document.querySelector('#connect').disabled = true;
  message.textContent = 'Đang kết nối session…';
  try {
    app = await createFastboard({
      sdkConfig: { appIdentifier: document.querySelector('#appId').value.trim(), region: document.querySelector('#region').value },
      joinRoom: { uuid: document.querySelector('#roomId').value.trim(), roomToken: document.querySelector('#roomToken').value.trim(), uid: 'teacher-companion', isWritable: true },
    });
    ui = createUI();
    ui.mount(document.querySelector('#board'), { app });
    document.querySelector('#roomToken').value = '';
    document.querySelector('#setup').style.display = 'none';
  } catch (error) {
    message.textContent = 'Không kết nối được. Kiểm tra app identifier, room/token, region và mạng. ' + String(error.message || error);
    document.querySelector('#connect').disabled = false;
  }
});
window.addEventListener('pagehide', () => { if (ui) ui.destroy(); if (app) void app.destroy(); });
