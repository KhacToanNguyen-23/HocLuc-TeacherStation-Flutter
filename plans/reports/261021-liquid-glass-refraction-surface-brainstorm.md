# Brainstorm: Board-aware liquid glass shader surfaces

**Date:** 2026-10-21

## Ideas Explored

- Apply a WebGL library only inside the plugin page. This is close to the reference but its renderer captures DOM within that WebView; it does not directly sample the Flutter board beneath the native surface.
- Move the plugin result card to Flutter. That gives the host direct control of both pixels and shader but moves plugin-owned presentation into the microkernel host.
- Capture board images and stream them to WebView. This preserves the WebGL renderer but adds image transfer cost, latency, and refresh-rate limits.
- Keep plugin content in WebView and place a Flutter shader surface under the registered glass region. This lets the shader sample the real Flutter board/PDF while the plugin keeps its own text, tokens, and interactions. It requires a generic SDK region-bounds contract and Windows compositing verification.

## User's Direction

The user wants the liquid-glass refraction effect on both the floating Flutter tool dock and the plugin's result panel. The plugin panel must refract the actual board/PDF behind its WebView, not just the plugin page's own DOM. The user accepts that text contrast will depend more on the background. The selected architecture is a Flutter-owned shader layer synchronized beneath plugin glass regions, while plugin content remains in its WebView.

## Open Questions

- The phase 01 prototype demonstrates transparent WebView composition over the Flutter scene. It does not verify that a shader layer can stay aligned under live plugin content or that its refraction samples the external board after all native composition layers are active. Treat this as a prototype gate in the plan.
- Keep initial delivery Windows desktop, matching the previous scope. Web synchronization remains deferred.

## Risks

- WebView/Flutter z-order, device-pixel-ratio conversion, scrolling, and dynamic layout can misalign the Flutter shader under the plugin card.
- Repainting a backdrop shader during dense board strokes or dock dragging can miss the 55 FPS frame-time target.
- Lower text contrast is an accepted visual tradeoff, but focus rings, button semantics, keyboard use, and a Solid preset must remain available.
