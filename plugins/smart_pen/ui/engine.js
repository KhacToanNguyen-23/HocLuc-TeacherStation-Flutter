(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.HocLucSmartPenEngine = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const markerPattern = /^[\[(]?([A-D])[.:\uFF1A)\]]?$/i;
  const attachedMarkerPattern = /^([\[(]?([A-D])[.:\uFF1A)\]])\s*(.+)$/i;

  function finite(value) {
    return typeof value === 'number' && Number.isFinite(value);
  }

  function normalizeFragment(fragment) {
    const bounds = fragment && fragment.bounds;
    if (typeof fragment?.text !== 'string' || !bounds) return null;
    const { x, y, width, height } = bounds;
    if (![x, y, width, height].every(finite) || width <= 0 || height <= 0) {
      return null;
    }
    const text = fragment.text.trim();
    const exact = text.match(markerPattern);
    const attached = exact ? null : text.match(attachedMarkerPattern);
    const label = (exact?.[1] || attached?.[2] || '').toUpperCase();
    if (!label) return null;

    const markerWidth = attached ? Math.min(width, Math.max(height * 1.2, 10)) : width;
    return {
      label,
      x,
      y,
      width: markerWidth,
      height,
      centerX: x + markerWidth / 2,
      centerY: y + height / 2,
    };
  }

  function median(values) {
    if (!values.length) return 10;
    const ordered = [...values].sort((a, b) => a - b);
    const middle = Math.floor(ordered.length / 2);
    return ordered.length % 2
      ? ordered[middle]
      : (ordered[middle - 1] + ordered[middle]) / 2;
  }

  function classifyPage(payload) {
    if (Array.isArray(payload?.answer_candidates)) {
      const pageNumber = Number(payload.page_number) || 0;
      const pageWidth = Number(payload?.page_size?.width);
      const pageHeight = Number(payload?.page_size?.height);
      return payload.answer_candidates.flatMap((candidate) => {
        const bounds = candidate?.bounds;
        if (!bounds || ![bounds.x, bounds.y, bounds.width, bounds.height].every(finite) ||
            bounds.x < 0 || bounds.y < 0 || bounds.width <= 0 || bounds.height <= 0 ||
            (finite(pageWidth) && bounds.x + bounds.width > pageWidth) ||
            (finite(pageHeight) && bounds.y + bounds.height > pageHeight)) return [];
        const label = typeof candidate.label === 'string' ? candidate.label.toUpperCase() : '';
        const groupId = typeof candidate.group_id === 'string' ? candidate.group_id : '';
        if (!/^[A-D]$/.test(label) || !groupId) return [];
        const centerX = bounds.x + bounds.width / 2;
        const centerY = bounds.y + bounds.height / 2;
        const id = `page-${pageNumber}-option-${label}-${Math.round(centerX)}-${Math.round(centerY)}`;
        return [{
          id,
          label,
          group_id: groupId,
          source_group_id: groupId,
          bounds: { ...bounds },
        }];
      }).sort((a, b) => a.bounds.y - b.bounds.y || a.bounds.x - b.bounds.x);
    }

    const fragments = Array.isArray(payload?.fragments) ? payload.fragments : [];
    const markers = fragments.map(normalizeFragment).filter(Boolean);
    if (!markers.length) return [];
    const typicalHeight = median(markers.map((marker) => marker.height));
    const rowTolerance = Math.max(typicalHeight * 0.55, 1);
    const xTolerance = Math.max(typicalHeight * 2.5, 12);
    const groups = [];
    const sorted = [...markers].sort((a, b) => a.centerY - b.centerY || a.x - b.x);
    const rows = [];

    for (const marker of sorted) {
      let row = null;
      for (let index = rows.length - 1; index >= 0; index -= 1) {
        const candidate = rows[index];
        const delta = marker.centerY - candidate.centerY;
        if (delta > rowTolerance) break;
        if (Math.abs(delta) <= rowTolerance) {
          row = candidate;
          break;
        }
      }
      if (row) {
        row.markers.push(marker);
        row.centerY = row.markers.reduce((sum, item) => sum + item.centerY, 0) / row.markers.length;
      } else {
        rows.push({ centerY: marker.centerY, markers: [marker] });
      }
    }

    // Four horizontally ordered options on one visual row form one answer.
    const consumed = new Set();
    const inlineRuns = [];
    for (const row of rows) {
      const inline = [...row.markers].sort((a, b) => a.centerX - b.centerX);
      let run = [];
      let previousRank = -1;
      for (const marker of inline) {
        const rank = marker.label.charCodeAt(0) - 65;
        if (run.length && rank <= previousRank) {
          if (run.length > 1) {
            inlineRuns.push(run);
            run.forEach((item) => consumed.add(item));
          }
          run = [];
        }
        run.push(marker);
        previousRank = rank;
      }
      if (run.length > 1) {
        inlineRuns.push(run);
        run.forEach((item) => consumed.add(item));
      }
    }

    // Join partial horizontal rows such as A/B followed by C/D. If OCR misses
    // one letter, the detected choices still share the question's group.
    const rowGroups = [];
    inlineRuns.sort((a, b) => a[0].centerY - b[0].centerY || a[0].x - b[0].x);
    for (const group of inlineRuns) {
      const first = group[0];
      const firstRank = first.label.charCodeAt(0) - 65;
      const groupCenterX = group.reduce((sum, marker) => sum + marker.centerX, 0) / group.length;
      const candidates = rowGroups
        .map((candidate) => {
          const last = candidate.markers.at(-1);
          const previousRank = last.label.charCodeAt(0) - 65;
          const centerX = candidate.markers.reduce((sum, marker) => sum + marker.centerX, 0) / candidate.markers.length;
          const gap = first.centerY - candidate.lastRowY;
          return { candidate, previousRank, centerX, gap };
        })
        .filter(({ previousRank, centerX, gap }) =>
          gap > 0 && gap <= typicalHeight * 2.7 &&
          firstRank > previousRank &&
          Math.abs(groupCenterX - centerX) <= xTolerance * 2,
        )
        .sort((a, b) => a.gap - b.gap || Math.abs(groupCenterX - a.centerX) - Math.abs(groupCenterX - b.centerX));
      if (candidates.length) {
        candidates[0].candidate.markers.push(...group);
        candidates[0].candidate.lastRowY = first.centerY;
      } else {
        rowGroups.push({ markers: [...group], lastRowY: first.centerY });
      }
    }
    groups.push(...rowGroups.map((group) => group.markers || group));

    // Reconstruct vertical option columns first. This keeps side-by-side
    // questions separate while allowing A/C and B/D columns to be paired.
    const columns = [];
    for (const marker of sorted.filter((item) => !consumed.has(item)).sort((a, b) => a.centerX - b.centerX)) {
      let column = columns.find((candidate) =>
        Math.abs(candidate.centerX - marker.centerX) <= xTolerance,
      );
      if (!column) {
        column = { centerX: marker.centerX, markers: [] };
        columns.push(column);
      }
      column.markers.push(marker);
      column.centerX = column.markers.reduce((sum, item) => sum + item.centerX, 0) / column.markers.length;
    }

    const runs = [];
    for (const column of columns) {
      const items = column.markers.sort((a, b) => a.centerY - b.centerY);
      let run = [];
      for (const marker of items) {
        const previous = run.at(-1);
        const rank = marker.label.charCodeAt(0) - 65;
        const previousRank = previous ? previous.label.charCodeAt(0) - 65 : -1;
        const verticalGap = previous ? marker.centerY - previous.centerY : 0;
        if (run.length && (rank <= previousRank || verticalGap > typicalHeight * 2.7)) {
          runs.push(run);
          run = [];
        }
        run.push(marker);
      }
      if (run.length) runs.push(run);
    }

    const consumedRuns = new Set();
    for (let i = 0; i < runs.length; i += 1) {
      if (consumedRuns.has(i)) continue;
      const first = [...runs[i]].sort((a, b) => a.centerY - b.centerY);
      if (first.length === 2 && first[0].label === 'A' && first[1].label === 'C') {
        const matches = [];
        for (let j = i + 1; j < runs.length; j += 1) {
          if (consumedRuns.has(j)) continue;
          const second = [...runs[j]].sort((a, b) => a.centerY - b.centerY);
          if (second.length !== 2 || second[0].label !== 'B' || second[1].label !== 'D') continue;
          if (Math.abs(first[0].centerY - second[0].centerY) > rowTolerance * 1.5 ||
              Math.abs(first[1].centerY - second[1].centerY) > rowTolerance * 1.5) continue;
          const firstX = first.reduce((sum, item) => sum + item.centerX, 0) / first.length;
          const secondX = second.reduce((sum, item) => sum + item.centerX, 0) / second.length;
          const pageWidth = Number(payload?.page_size?.width);
          const horizontalGap = Math.abs(firstX - secondX);
          if (horizontalGap <= xTolerance ||
              (finite(pageWidth) && horizontalGap > pageWidth * 0.8)) continue;
          matches.push({ index: j, markers: second, distance: Math.abs(firstX - secondX) });
        }
        if (matches.length === 1) {
          const match = matches[0];
          groups.push([...first, ...match.markers].sort((a, b) => a.centerY - b.centerY || a.x - b.x));
          consumedRuns.add(i);
          consumedRuns.add(match.index);
          continue;
        }
      }
      groups.push(first);
      consumedRuns.add(i);
    }

    groups.sort((a, b) => a[0].centerY - b[0].centerY || a[0].x - b[0].x);

    const pageNumber = Number(payload?.page_number) || 0;
    const pageWidth = Number(payload?.page_size?.width);
    const pageHeight = Number(payload?.page_size?.height);
    return groups.flatMap((group) => {
      const seenLabels = new Set();
      const anchor = group[0];
      const groupId = `page-${pageNumber}-question-${Math.round(anchor.centerY)}-${Math.round(anchor.x)}`;
      return group
        .sort((a, b) => a.centerY - b.centerY || a.x - b.x)
        .filter((marker) => {
          if (seenLabels.has(marker.label)) return false;
          seenLabels.add(marker.label);
          return true;
        })
        .map((marker) => {
          // OCR bounds already cover the answer marker. Keep a small margin
          // proportional to its glyph height so the target follows PDF scale.
          const padding = marker.height * 0.12;
          const x = Math.max(0, marker.x - padding);
          const y = Math.max(0, marker.y - padding);
          const width = Math.min(
            marker.width + padding * 2,
            finite(pageWidth) ? Math.max(pageWidth - x, 0) : Number.POSITIVE_INFINITY,
          );
          const height = Math.min(
            marker.height + padding * 2,
            finite(pageHeight) ? Math.max(pageHeight - y, 0) : Number.POSITIVE_INFINITY,
          );
          const id = `page-${pageNumber}-option-${marker.label}-${Math.round(marker.centerX)}-${Math.round(marker.centerY)}`;
          return {
            id,
            label: marker.label,
            group_id: groupId,
            source_group_id: groupId,
            bounds: { x, y, width, height },
          };
        })
        .filter((region) => region.bounds.width > 0 && region.bounds.height > 0);
    });
  }

  function linkAdjacentPages(pagePayloads) {
    const orderedPages = [...pagePayloads].sort((a, b) => a.page_number - b.page_number);
    const groups = new Map();
    const edgeByKey = new Map();
    const parent = new Map();
    const existingGroupKeys = new Map();
    const rootOf = (key) => {
      const current = parent.get(key);
      if (current === key) return key;
      const rootKey = rootOf(current);
      parent.set(key, rootKey);
      return rootKey;
    };
    const union = (left, right) => {
      const leftRoot = rootOf(left);
      const rightRoot = rootOf(right);
      if (leftRoot === rightRoot) return;
      if (leftRoot < rightRoot) parent.set(rightRoot, leftRoot);
      else parent.set(leftRoot, rightRoot);
    };

    for (const page of orderedPages) {
      const grouped = new Map();
      for (const region of page.regions || []) {
        const sourceId = region.source_group_id || region.group_id;
        if (!grouped.has(sourceId)) grouped.set(sourceId, []);
        grouped.get(sourceId).push(region);
      }
      const pageGroups = [];
      for (const [groupId, regions] of grouped) {
        const key = `${page.page_number}::${groupId}`;
        parent.set(key, key);
        if (!existingGroupKeys.has(groupId)) existingGroupKeys.set(groupId, []);
        existingGroupKeys.get(groupId).push(key);
        const pageHeight = Number(page.page_size?.height) || 1;
        const pageWidth = Number(page.page_size?.width) || 1;
        const top = Math.min(...regions.map((region) => region.bounds.y));
        const bottom = Math.max(...regions.map((region) => region.bounds.y + region.bounds.height));
        const centerX = regions.reduce((sum, region) => sum + region.bounds.x + region.bounds.width / 2, 0) / regions.length;
        pageGroups.push({
          key,
          pageNumber: page.page_number,
          labels: new Set(regions.map((region) => region.label)),
          edge: bottom / pageHeight >= 0.82 ? 'bottom' : top / pageHeight <= 0.18 ? 'top' : null,
          centerX: centerX / pageWidth,
          complete: regions.length >= 4,
        });
        edgeByKey.set(key, pageGroups[pageGroups.length - 1].edge);
      }
      groups.set(page.page_number, pageGroups);
    }

    for (const keys of existingGroupKeys.values()) {
      for (let index = 1; index < keys.length; index += 1) {
        union(keys[0], keys[index]);
      }
    }

    for (let pageIndex = 0; pageIndex + 1 < orderedPages.length; pageIndex += 1) {
      const currentPage = orderedPages[pageIndex];
      const nextPage = orderedPages[pageIndex + 1];
      if (nextPage.page_number !== currentPage.page_number + 1) continue;
      const lower = (groups.get(currentPage.page_number) || []).filter((group) => group.edge === 'bottom' && !group.complete);
      const upper = (groups.get(nextPage.page_number) || []).filter((group) => group.edge === 'top' && !group.complete);
      const pairedUpper = new Set();
      for (const lowerGroup of lower) {
        const match = upper
          .map((candidate) => ({
            candidate,
            distance: Math.abs(lowerGroup.centerX - candidate.centerX),
            overlaps: [...lowerGroup.labels].some((label) => candidate.labels.has(label)),
          }))
          .filter((item) => !item.overlaps && item.distance <= 0.08 && !pairedUpper.has(item.candidate.key))
          .sort((a, b) => a.distance - b.distance)[0];
        if (!match) continue;
        pairedUpper.add(match.candidate.key);
        union(lowerGroup.key, match.candidate.key);
      }
    }

    const canonical = new Map();
    for (const key of parent.keys()) canonical.set(key, `pdf-${rootOf(key)}`);
    const rootLabels = new Map();
    for (const pageGroups of groups.values()) {
      for (const group of pageGroups) {
        const root = rootOf(group.key);
        if (!rootLabels.has(root)) rootLabels.set(root, new Set());
        for (const label of group.labels) rootLabels.get(root).add(label);
      }
    }
    return orderedPages.map((page) => ({
      page_number: page.page_number,
      document_generation: page.document_generation,
      page_size: page.page_size,
      regions: (page.regions || []).filter((region) => {
        const key = `${page.page_number}::${region.source_group_id || region.group_id}`;
        // Keep interior OCR hits clickable even if they are the only label
        // detected. Edge fragments remain pending until they can link across
        // the page boundary, avoiding false cross-page selections.
        return (
          rootLabels.get(rootOf(key)).size >= 2 || edgeByKey.get(key) == null
        );
      }).map((region) => ({
        ...region,
        source_group_id: region.source_group_id || region.group_id,
        group_id: canonical.get(`${page.page_number}::${region.source_group_id || region.group_id}`) || region.group_id,
      })),
    }));
  }

  function createAnnotation(region, pageSize) {
    const { x, y, width, height } = region.bounds;
    const cx = x + width / 2;
    const cy = y + height / 2;
    // A gently uneven closed pen loop. Keep the perturbation deterministic so
    // repeated marking, persistence and rendering produce the same shape.
    const rx = width / 2 + height * 0.025;
    const ry = height / 2 + height * 0.025;
    const phase = ((String(region.label || '').charCodeAt(0) || 65) % 7) * 0.13;
    const points = Array.from({ length: 48 }, (_, index) => {
      const angle = 2 * Math.PI * index / 48;
      const radial =
        1 +
        0.018 * Math.sin(3 * angle + phase) +
        0.012 * Math.sin(5 * angle - phase * 0.7);
      const offsetX = height * 0.012 * Math.sin(angle + phase);
      const offsetY = height * 0.01 * Math.cos(2 * angle - phase);
      return [
        Math.min(1, Math.max(0, (cx + offsetX + Math.cos(angle) * rx * radial) / pageSize.width)),
        Math.min(1, Math.max(0, (cy + offsetY + Math.sin(angle) * ry * radial) / pageSize.height)),
      ];
    });
    return { points, color: 0xffd93636, width: 1.5 };
  }

  return { classifyPage, linkAdjacentPages, createAnnotation };
});
