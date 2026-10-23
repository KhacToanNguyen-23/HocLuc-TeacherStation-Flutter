/**
 * Hoc Luc Plugin SDK (hocluc-plugin-sdk.js)
 * Standard RPC bridge between Plugin Webview and Hoc Luc Teacher Station Desktop Host.
 *
 * Version: 2.0.0
 * Protocol: Typed RPC via window.chrome.webview.postMessage
 */

(function (root, factory) {
  if (typeof define === 'function' && define.amd) {
    define([], factory);
  } else if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.HocLuc = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const pendingRequests = new Map();
  const hostEventHandlers = new Map();
  let requestCounter = 0;

  function generateRequestId() {
    return 'req_' + Date.now() + '_' + ++requestCounter;
  }

  function isHostAvailable() {
    return (
      typeof window !== 'undefined' &&
      window.chrome &&
      window.chrome.webview &&
      typeof window.chrome.webview.postMessage === 'function'
    );
  }

  function sendRpc(action, payload) {
    return new Promise((resolve, reject) => {
      const id = generateRequestId();
      const message = {
        id,
        action,
        payload: payload || {},
        host_generation: Number(window.__HocLucHostGeneration) || 0,
      };

      const timeoutId = setTimeout(() => {
        if (pendingRequests.has(id)) {
          pendingRequests.delete(id);
          reject(new Error(`[HocLucSDK] Timeout waiting for host action '${action}'`));
        }
      }, 8000);
      pendingRequests.set(id, { resolve, reject, timeoutId });

      // Fallback timeout sau 8 giây nếu host không phản hồi
      if (isHostAvailable()) {
        try {
          window.chrome.webview.postMessage(JSON.stringify(message));
        } catch (err) {
          pendingRequests.delete(id);
          clearTimeout(timeoutId);
          reject(err);
        }
      } else {
        // Mock fallback for browser development without Flutter host
        console.warn(`[HocLucSDK] Host not available. Mocking RPC: ${action}`, payload);
        setTimeout(() => {
          handleHostResponse({ id, success: true, data: null });
        }, 50);
      }
    });
  }

  function handleHostResponse(response) {
    if (!response || !response.id) return;
    const pending = pendingRequests.get(response.id);
    if (!pending) return;

    pendingRequests.delete(response.id);
    clearTimeout(pending.timeoutId);
    if (response.success) {
      pending.resolve(response.data);
    } else {
      pending.reject(new Error(response.error || 'Unknown host error'));
    }
  }

  function dispatchHostEvent(message) {
    if (!message || typeof message.event !== 'string') return;
    const handlers = hostEventHandlers.get(message.event);
    if (!handlers) return;
    handlers.forEach((handler) => handler(message.payload || {}));
  }

  // Lắng nghe phản hồi từ Flutter Webview
  if (typeof window !== 'undefined') {
    window.__hocluc_handle_response = handleHostResponse;
    window.__hocluc_dispatch_host_event = dispatchHostEvent;

    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.addEventListener('message', function (event) {
        try {
          const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
          handleHostResponse(data);
        } catch (e) {
          console.error('[HocLucSDK] Parse message error:', e);
        }
      });
    }
  }

  const glassRegions = new Map();

  function postGlassAction(action, payload) {
    return sendRpc(action, payload).catch((error) => {
      console.warn('[HocLucSDK] Glass region request failed:', error);
      return null;
    });
  }

  function scheduleGlassMeasurement(region) {
    if (region.disposed || region.frame !== null) return;
    const requestFrame = window.requestAnimationFrame ||
      ((callback) => window.setTimeout(callback, 16));
    region.frame = requestFrame(() => {
      region.frame = null;
      measureGlassRegion(region);
    });
  }

  function measureGlassRegion(region) {
    if (region.disposed) return;
    const element = region.element;
    if (!element || element.isConnected === false) {
      unregisterGlassRegion(region.id);
      return;
    }

    let rect;
    try {
      rect = element.getBoundingClientRect();
    } catch (_) {
      unregisterGlassRegion(region.id);
      return;
    }
    const rootElement = document.documentElement || {};
    const viewport = {
      width: Number(rootElement.clientWidth || window.innerWidth),
      height: Number(rootElement.clientHeight || window.innerHeight),
    };
    let visibleStyle = true;
    let effectiveOpacity = 1;
    try {
      if (window.getComputedStyle) {
        for (let current = element; current; current = current.parentElement) {
          const style = window.getComputedStyle(current) || {};
          const opacity = Number(style.opacity);
          if (style.display === 'none' || style.visibility === 'hidden' ||
              style.visibility === 'collapse' || (Number.isFinite(opacity) && opacity <= 0)) {
            visibleStyle = false;
            break;
          }
          if (Number.isFinite(opacity)) effectiveOpacity *= opacity;
        }
      }
    } catch (_) {}
    const visible = !!rect &&
      Number.isFinite(rect.x) && Number.isFinite(rect.y) &&
      Number.isFinite(rect.width) && Number.isFinite(rect.height) &&
      rect.width > 0 && rect.height > 0 &&
      visibleStyle && effectiveOpacity > 0;
    if (isHostAvailable() && !(Number(window.__HocLucHostGeneration) > 0)) {
      // Navigation completion assigns the document generation and explicitly
      // refreshes regions. Keep this measurement retryable until then.
      return;
    }
    const payload = {
      region_id: region.id,
      bounds: {
        x: Number(rect && rect.x) || 0,
        y: Number(rect && rect.y) || 0,
        width: Number(rect && rect.width) || 0,
        height: Number(rect && rect.height) || 0,
      },
      viewport,
      visible,
    };
    const signature = JSON.stringify(payload);
    if (signature === region.lastSignature) return;
    region.lastSignature = signature;
    const action = region.registered ? 'glass:update' : 'glass:register';
    region.registered = true;
    postGlassAction(action, payload);
  }

  function unregisterGlassRegion(regionId) {
    const region = glassRegions.get(regionId);
    if (!region) return Promise.resolve(false);
    glassRegions.delete(regionId);
    region.disposed = true;
    if (region.frame !== null) {
      const cancelFrame = window.cancelAnimationFrame || window.clearTimeout;
      if (cancelFrame) cancelFrame(region.frame);
    }
    if (region.resizeObserver) region.resizeObserver.disconnect();
    if (region.mutationObserver) region.mutationObserver.disconnect();
    window.removeEventListener('scroll', region.onViewportChange, true);
    window.removeEventListener('resize', region.onViewportChange);
    if (!region.registered) return Promise.resolve(false);
    return postGlassAction('glass:unregister', { region_id: regionId });
  }

  function registerGlassRegion(regionId, element) {
    if (typeof regionId !== 'string' || !/^[A-Za-z0-9_.:-]{1,128}$/.test(regionId)) {
      throw new TypeError('glass.registerRegion requires a valid region ID');
    }
    if (!element || typeof element.getBoundingClientRect !== 'function') {
      throw new TypeError('glass.registerRegion requires a DOM element');
    }
    if (glassRegions.has(regionId)) unregisterGlassRegion(regionId);

    const region = {
      id: regionId,
      element,
      frame: null,
      registered: false,
      disposed: false,
      lastSignature: null,
      resizeObserver: null,
      mutationObserver: null,
      onViewportChange: null,
    };
    region.onViewportChange = () => scheduleGlassMeasurement(region);
    if (typeof ResizeObserver === 'function') {
      region.resizeObserver = new ResizeObserver(region.onViewportChange);
      region.resizeObserver.observe(element);
    }
    if (typeof MutationObserver === 'function') {
      region.mutationObserver = new MutationObserver(region.onViewportChange);
      const mutationRoot = element.parentElement || document.documentElement;
      if (mutationRoot) {
        region.mutationObserver.observe(mutationRoot, {
          attributes: true,
          childList: true,
          subtree: true,
        });
      }
      for (let ancestor = element; ancestor; ancestor = ancestor.parentElement) {
        if (ancestor === mutationRoot) continue;
        region.mutationObserver.observe(ancestor, { attributes: true });
      }
    }
    window.addEventListener('scroll', region.onViewportChange, true);
    window.addEventListener('resize', region.onViewportChange);
    glassRegions.set(regionId, region);
    scheduleGlassMeasurement(region);
    return () => glassRegions.get(regionId) === region
      ? unregisterGlassRegion(regionId)
      : Promise.resolve(false);
  }

  function updateGlassRegion(regionId) {
    const region = glassRegions.get(regionId);
    if (!region) return Promise.resolve(false);
    region.lastSignature = null;
    scheduleGlassMeasurement(region);
    return Promise.resolve(true);
  }

  function refreshGlassRegions() {
    glassRegions.forEach((region) => {
      region.lastSignature = null;
      scheduleGlassMeasurement(region);
    });
  }

  if (typeof window !== 'undefined') {
    window.addEventListener('pagehide', () => {
      Array.from(glassRegions.keys()).forEach(unregisterGlassRegion);
    });
  }

  const HocLuc = {
    version: '2.2.0',

    // Lấy thông tin ứng dụng host
    getContext: function () {
      return sendRpc('context:get', {});
    },

    onHostEvent: function (eventName, handler) {
      if (typeof eventName !== 'string' || typeof handler !== 'function') {
        throw new TypeError('onHostEvent requires an event name and callback');
      }
      const handlers = hostEventHandlers.get(eventName) || new Set();
      handlers.add(handler);
      hostEventHandlers.set(eventName, handlers);
      return function unsubscribe() { handlers.delete(handler); };
    },

    __dispatchHostEvent: dispatchHostEvent,

    glass: {
      registerRegion: registerGlassRegion,
      updateRegion: updateGlassRegion,
      unregisterRegion: unregisterGlassRegion,
      refreshRegions: refreshGlassRegions
    },

    // Các tương tác với Bảng phấn và Tài liệu
    board: {
      getSelectedText: function () {
        return sendRpc('board:get_selected_text', {});
      },

      insertAnnotation: function (annotation) {
        // annotation: { type: 'sticker' | 'latex' | 'text', data: { ... } }
        return sendRpc('board:insert_annotation', annotation);
      },

      clearAnnotations: function () {
        return sendRpc('board:clear_annotations', {});
      },
      startSnipSelection: function (target) {
        return sendRpc('START_SNIP_SELECTION', { target });
      },
      setTool: function (target, enabled) {
        return sendRpc('board:set_tool', { target, enabled });
      },
      publishPdfRegions: function (pageNumber, documentGeneration, pageSize, regions) {
        return sendRpc('board:publish_pdf_regions', {
          page_number: pageNumber,
          document_generation: documentGeneration,
          page_size: pageSize,
          regions: regions || []
        });
      },
      rekeyPdfAnnotationGroup: function (documentGeneration, fromGroupId, toGroupId, affectedPages) {
        return sendRpc('board:rekey_pdf_annotation_group', {
          document_generation: documentGeneration,
          from_group_id: fromGroupId,
          to_group_id: toGroupId,
          affected_pages: affectedPages || []
        });
      },
      togglePdfAnnotation: function (pageNumber, documentGeneration, pageSize, region, affectedPages, options) {
        return sendRpc('board:toggle_pdf_annotation', {
          page_number: pageNumber,
          document_generation: documentGeneration,
          page_size: pageSize,
          region,
          affected_pages: affectedPages || [],
          stroke: options && options.stroke,
          persist: !options || options.persist !== false
        });
      }
    },

    // Lưu trữ key-value an toàn của plugin
    storage: {
      get: function (key) {
        return sendRpc('storage:get', { key });
      },
      set: function (key, value) {
        return sendRpc('storage:set', { key, value });
      }
    }
  };

  return HocLuc;
});
