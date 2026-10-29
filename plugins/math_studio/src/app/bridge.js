/**
 * HocLuc Plugin SDK Bridge for Math Studio.
 * Interfaces with real `window.HocLuc` provided by PluginWebServer.
 */

export const Bridge = {
  isAvailable() {
    return typeof window !== 'undefined' && typeof window.HocLuc !== 'undefined';
  },

  /**
   * Inserts an annotation card onto the chalkboard canvas.
   * Supports both flat options and nested `{ data: ... }` payloads.
   * @param {object} options
   * @returns {Promise<boolean>}
   */
  async insertAnnotation(options = {}) {
    if (!this.isAvailable() || !window.HocLuc.board || typeof window.HocLuc.board.insertAnnotation !== 'function') {
      console.warn('[Bridge] HocLuc SDK board.insertAnnotation is not available in current environment.');
      return false;
    }

    try {
      const data = options.data && typeof options.data === 'object' ? options.data : options;
      const title = data.title || options.title || 'Học Lực Math Studio';
      const imageBase64 = data.imageBase64 || options.imageBase64 || null;
      const svgContent = data.svgContent || options.svgContent || null;
      const aspectRatio = data.aspectRatio || options.aspectRatio || 1.6;
      const metadata = data.metadata || options.metadata || {};

      const annotationData = {
        title,
        aspectRatio,
        metadata,
      };

      if (imageBase64) {
        annotationData.imageBase64 = imageBase64;
      }
      if (svgContent) {
        annotationData.svgContent = svgContent;
      }

      console.log('[Bridge] Sending insertAnnotation to host:', {
        title,
        hasImage: !!imageBase64,
        imageLength: imageBase64 ? imageBase64.length : 0,
        hasSvg: !!svgContent,
        svgLength: svgContent ? svgContent.length : 0,
        aspectRatio,
      });

      const res = await window.HocLuc.board.insertAnnotation({
        type: 'com.hocluc.plugin.math_studio',
        data: annotationData,
      });

      return !!res;
    } catch (err) {
      console.error('[Bridge] Failed to insert annotation to chalkboard:', err);
      return false;
    }
  },

  /**
   * Closes the plugin window.
   */
  close() {
    if (this.isAvailable()) {
      if (typeof window.HocLuc.close === 'function') {
        window.HocLuc.close();
        return;
      }
      if (window.HocLuc.window && typeof window.HocLuc.window.close === 'function') {
        window.HocLuc.window.close();
        return;
      }
    }
    console.log('[Bridge] Mock close triggered (no host window available).');
  },
};

