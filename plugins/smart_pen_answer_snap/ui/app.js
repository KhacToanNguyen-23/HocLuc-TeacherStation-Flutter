const status = document.querySelector('#status');

async function init() {
  try {
    await window.HocLuc.getContext();
    status.textContent = 'Plugin đã kết nối với bảng.';
  } catch (error) {
    status.textContent = 'Chưa kết nối được với bảng.';
  }
}

init();
