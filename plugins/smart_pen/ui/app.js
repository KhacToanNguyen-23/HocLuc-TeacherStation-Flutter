const button = document.getElementById('toggle');
const status = document.getElementById('status');
let enabled = false;
let receivedToolState = false;
let documentGeneration = null;
const target = 'answer_marker';
const pages = new Map();
const sourcePages = new Map();
let pending = Promise.resolve();
function enqueue(task) {
  pending = pending.then(task).catch((error) => {
    status.textContent = `Không thể xử lý PDF: ${error.message}`;
  });
  return pending;
}

window.HocLuc?.getContext()
  .then((result) => {
    if (!receivedToolState) enabled = result?.activeTool === target;
    render();
  })
  .catch(() => render());

window.HocLuc?.onHostEvent('board:tool_state', (payload) => {
  receivedToolState = true;
  enabled = payload?.active_tool === target;
  render();
});

window.HocLuc?.onHostEvent('board:pdf_text_fragments', (payload) => enqueue(async () => {
  if (!Number.isInteger(payload?.page_number)) return;
  const regions = window.HocLucSmartPenEngine?.classifyPage(payload) ?? [];
  if (documentGeneration !== payload.document_generation) {
    documentGeneration = payload.document_generation;
    pages.clear();
    sourcePages.clear();
  }
  sourcePages.set(payload.page_number, { ...payload, regions });
  const linkedPages = window.HocLucSmartPenEngine?.linkAdjacentPages([...sourcePages.values()]) ?? [];
  const migrations = new Map();
  for (const page of linkedPages) {
    const previous = new Map((pages.get(page.page_number)?.regions || []).map((region) => [region.id, region]));
    for (const region of page.regions) {
      const old = previous.get(region.id);
      if (old && old.group_id !== region.group_id) migrations.set(old.group_id, region.group_id);
    }
  }
  for (const [from, to] of migrations) {
    await window.HocLuc.board.rekeyPdfAnnotationGroup(
      documentGeneration, from, to, linkedPages.map((page) => page.page_number),
    );
  }
  for (const page of linkedPages) {
    pages.set(page.page_number, page);
    await window.HocLuc.board.publishPdfRegions(
      page.page_number, page.document_generation, page.page_size, page.regions,
    );
  }
  status.textContent = `Đã phân tích trang ${payload.page_number}: ${regions.length} vùng đáp án.`;
}));

window.HocLuc?.onHostEvent('board:pdf_tap', (payload) => enqueue(async () => {
  if (payload?.document_generation !== documentGeneration) return;
  const page = pages.get(payload.page_number);
  if (!page) return;
  const point = payload.page_point;
  if (!point || !Number.isFinite(point.x) || !Number.isFinite(point.y)) return;
  const tolerance = Number.isFinite(payload.hit_tolerance)
    ? Math.max(0, payload.hit_tolerance)
    : 0;
  const region = page.regions
    .filter(({ bounds }) =>
      point.x >= bounds.x - tolerance &&
      point.x <= bounds.x + bounds.width + tolerance &&
      point.y >= bounds.y - tolerance &&
      point.y <= bounds.y + bounds.height + tolerance,
    )
    .map((candidate) => ({
      candidate,
      distance: Math.hypot(
        point.x - (candidate.bounds.x + candidate.bounds.width / 2),
        point.y - (candidate.bounds.y + candidate.bounds.height / 2),
      ),
    }))
    .sort((a, b) => a.distance - b.distance)[0]?.candidate;
  if (!region) {
    status.textContent = `No answer marker near PDF point (${point.x.toFixed(1)}, ${point.y.toFixed(1)}).`;
    console.debug('[Smart Pen] PDF tap did not hit an answer', {
      page: payload.page_number,
      point,
      tolerance,
    });
    return;
  }
  const affectedPages = [...pages.values()]
    .filter((candidatePage) => candidatePage.regions.some(
      (candidate) => candidate.group_id === region.group_id,
    ))
    .map((candidatePage) => candidatePage.page_number);
  try {
    await window.HocLuc.board.togglePdfAnnotation(
      payload.page_number,
      payload.document_generation,
      page.page_size,
      region,
      affectedPages,
      { stroke: window.HocLucSmartPenEngine.createAnnotation(region, page.page_size) },
    );
    console.debug('[Smart Pen] PDF answer hit', {
      page: payload.page_number,
      point,
      label: region.label,
      regionId: region.id,
      questionGroup: region.group_id,
      annotationGroup: region.annotation_group_id,
      bounds: region.bounds,
    });
    status.textContent = `Marked ${region.label} at PDF point (${point.x.toFixed(1)}, ${point.y.toFixed(1)}); marker center (${(region.bounds.x + region.bounds.width / 2).toFixed(1)}, ${(region.bounds.y + region.bounds.height / 2).toFixed(1)}).`;
  } catch (error) {
    status.textContent = `Không thể cập nhật dấu đáp án: ${error.message}`;
  }
}));

button.addEventListener('click', async () => {
  enabled = !enabled;
  try {
    const result = await window.HocLuc.board.setTool(target, enabled);
    enabled = result?.active === true;
    render();
  } catch (error) {
    enabled = !enabled;
    status.textContent = `Không thể đổi công cụ: ${error.message}`;
    render();
  }
});

function render() {
  button.textContent = enabled ? 'Tắt công cụ' : 'Bật công cụ';
  status.textContent = enabled
    ? 'Đang bật. Chọn công cụ trong thanh công cụ để dùng trên PDF.'
    : 'Đang tắt.';
}
