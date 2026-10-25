# Liquid glass contrast matrix

Phase 04 accessibility evidence for the bounded Windows desktop implementation. Ratios use WCAG relative luminance for the listed sRGB colors. The fixture colors represent the chalkboard, a white PDF page, alternating black and white regions, and saturated board/PDF marks. These fixtures do not claim coverage of arbitrary content.

## Plugin UI

Text-bearing plugin surfaces use the opaque local backing `#182620` in Clear, Frosted, and Solid modes. Therefore fixture content does not blend into the text backing. S/V/O tags retain their role tint as a shallow gradient over the opaque backing; ratios below use the resulting backing color. Normal text requires 4.5:1.

| Preset | Backing / text pair | Chalkboard `#14221d` | White PDF `#ffffff` | Black region `#000000` | White region `#ffffff` | Red `#d50000` | Blue `#1e40af` | Yellow `#fbbf24` |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Clear | Normal `#e6ede8` / `#182620` | 13.20 | 13.20 | 13.20 | 13.20 | 13.20 | 13.20 | 13.20 |
| Frosted | Normal `#e6ede8` / `#182620` | 13.20 | 13.20 | 13.20 | 13.20 | 13.20 | 13.20 | 13.20 |
| Solid | Normal `#e6ede8` / `#182620` | 13.20 | 13.20 | 13.20 | 13.20 | 13.20 | 13.20 | 13.20 |
| Clear | Subject `#38bdf8` / tinted `#1d3e43` | 5.38 | 5.38 | 5.38 | 5.38 | 5.38 | 5.38 | 5.38 |
| Frosted | Subject `#38bdf8` / tinted `#1d3e43` | 5.38 | 5.38 | 5.38 | 5.38 | 5.38 | 5.38 | 5.38 |
| Solid | Subject `#38bdf8` / tinted `#1d3e43` | 5.38 | 5.38 | 5.38 | 5.38 | 5.38 | 5.38 | 5.38 |
| Clear | Verb `#f472b6` / tinted `#3b3238` | 4.67 | 4.67 | 4.67 | 4.67 | 4.67 | 4.67 | 4.67 |
| Frosted | Verb `#f472b6` / tinted `#3b3238` | 4.67 | 4.67 | 4.67 | 4.67 | 4.67 | 4.67 | 4.67 |
| Solid | Verb `#f472b6` / tinted `#3b3238` | 4.67 | 4.67 | 4.67 | 4.67 | 4.67 | 4.67 | 4.67 |
| Clear | Object `#fb923c` / tinted `#3f3825` | 5.14 | 5.14 | 5.14 | 5.14 | 5.14 | 5.14 | 5.14 |
| Frosted | Object `#fb923c` / tinted `#3f3825` | 5.14 | 5.14 | 5.14 | 5.14 | 5.14 | 5.14 | 5.14 |
| Solid | Object `#fb923c` / tinted `#3f3825` | 5.14 | 5.14 | 5.14 | 5.14 | 5.14 | 5.14 | 5.14 |

Plugin button labels (`#cdd6f4`) contrast at 7.18:1 over the blue tint endpoint `#2e415b` and 7.29:1 over the purple tint endpoint `#443c4a`. Grammar success text (`#4ade80`) is 9.01:1 and warning text (`#f87171`) is 5.68:1 on `#182620`. Each text combination exceeds 4.5:1.

## Flutter host dock and palette

Host dock labels use opaque control fills: inactive `#1e293b` with white text (14.63:1), active `#062653` with `#edf5ff` text (13.55:1). The visible palette boundary has a dark edge `#0b2348` and a light edge `#c4d6ec`; the dock control uses the light edge. At least one edge in each pair has at least 3:1 contrast against every fixture. Ratios are shown as dark edge / light edge / dock light border:

| Fixture | Edge contrast ratios |
|---|---:|
| Chalkboard `#14221d` | 1.06 / 16.45 / 11.11 |
| White PDF `#ffffff` | 15.58 / 1.00 / 1.48 |
| Black region `#000000` | 1.35 / 21.00 / 14.18 |
| White region `#ffffff` | 15.58 / 1.00 / 1.48 |
| Red `#d50000` | 2.84 / 5.48 / 3.70 |
| Blue `#1e40af` | 1.79 / 8.72 / 5.89 |
| Yellow `#fbbf24` | 9.33 / 1.67 / 1.13 |

The palette shell uses both edges. Dock button and preset button fills remain opaque and retain the added high contrast boundary over the same fixture set. Solid remains available as the strongest glass preset; text itself is backed opaquely for all three presets.

## Interaction accessibility

The preset control is keyboard focusable and Enter activates it; it exposes a semantic button label and selected preset state. Plugin button hover styling is restricted to `(hover: hover)`, keyboard focus has a visible outline, and reduced-motion disables transition and hover transform/shadow effects.

## Scope and evidence

The board beneath native WebView2 content is not visible through that content in this environment. Windows desktop uses the user-approved opaque WebView fallback; the Flutter dock/frame and plugin-internal surfaces retain glass styling. Flutter Web host-event synchronization is deferred. Phase 03 measured 30 Windows WebView event updates at 1.80 ms median, 3.20 ms p95, and 3.90 ms maximum; dock drag frame pacing was not measured and no 55 FPS claim is made. Contrast was calculated from the source colors and is covered by feature-local tests; arbitrary board/PDF colors remain outside this fixture guarantee.
