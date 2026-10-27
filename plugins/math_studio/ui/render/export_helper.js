/**
 * Export Helper & Host Bridge Integration
 * Encodes SVGs to base64 and dispatches insertAnnotation RPC to Studio Board.
 */

export function svgToBase64(svgString) {
  // UTF-8 safe base64 encoding
  const utf8Bytes = encodeURIComponent(svgString).replace(/%([0-9A-F]{2})/g, (match, p1) =>
    String.fromCharCode('0x' + p1)
  );
  return 'data:image/svg+xml;base64,' + btoa(utf8Bytes);
}

export async function insertToBoard({ title, rawText, svgContent, metadata, stickerId, aspectRatio }) {
  const imageBase64 = svgToBase64(svgContent);

  if (typeof window !== 'undefined' && window.HocLuc && window.HocLuc.board) {
    try {
      await window.HocLuc.board.insertAnnotation({
        type: 'com.hocluc.plugin.math_studio',
        data: {
          stickerId: stickerId || undefined,
          pluginId: 'com.hocluc.plugin.math_studio',
          aspectRatio: aspectRatio || undefined,
          title,
          rawText,
          svgContent,
          imageBase64,
          metadata: metadata || undefined
        }
      });
      return true;
    } catch (err) {
      console.error('[MathStudio] Insert to board failed:', err);
      throw err;
    }
  } else {
    console.warn('[MathStudio] HocLuc SDK not connected. Simulating insert to board.');
    return true;
  }
}

