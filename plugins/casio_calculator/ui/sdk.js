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
      const message = { id, action, payload: payload || {} };

      pendingRequests.set(id, { resolve, reject });

      // Fallback timeout sau 8 giây nếu host không phản hồi
      setTimeout(() => {
        if (pendingRequests.has(id)) {
          pendingRequests.delete(id);
          reject(new Error(`[HocLucSDK] Timeout waiting for host action '${action}'`));
        }
      }, 8000);

      if (isHostAvailable()) {
        try {
          window.chrome.webview.postMessage(JSON.stringify(message));
        } catch (err) {
          pendingRequests.delete(id);
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

  const HocLuc = {
    version: '2.0.0',

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
