# FreeHand Direct Translator — Phased Implementation Plan

## Overview

Replace the `libfreehand → librevenge SVG text → SVGParser → VectorShape` pipeline with a direct C++ walker over `FHCollector`'s private member maps that produces `[VectorShape]` via the existing C bridge boundary (`FreeHandBridge.h/.mm`). The translator preserves FreeHand structural intent (clip groups as real clipping, composite paths as compound paths, tile fills as resolved nested shape trees, text as `TypographyProperties`, raster images as `embeddedImageData`) without ever emitting a `data:image/svg+xml` round-trip.


## Architecture

### Current state
- `FreeHandImporter.parseToSVG(url:)` → `freehand_parse_to_svg` → libfreehand emits SVG via `RVNGSVGDrawingGenerator` → `stripUrlFills` → `VectorImportManager.importFreeHand` → `parseSVGContent` → `SVGParser` → flat `[VectorShape]`. Lossy for every FreeHand structure the C collector encoded as base64 SVG inside a bitmap fill.

### New pipeline
- `FreeHandImporter.parseToShapes(data:)` → new `freehand_parse_to_shapes` C entry point → new Obj-C++ file `FreeHandDirectTranslator.mm` → `FHCollector.inkpenBuildView(...)` → walker produces `[VectorShape]` directly.

### Why this architecture
- The Xcode target uses `PBXFileSystemSynchronizedRootGroup` — dropping `.mm/.cpp/.h` files into `logos inkpen.io/ThirdParty/libfreehand/` joins the target automatically, no pbxproj editing.
- The bridging header already exposes `FreeHandBridge.h`.
- Concrete `FHPathElement` subclasses are defined in an anonymous namespace inside `FHPath.cpp` and are invisible outside the TU. We iterate path geometry by calling the existing `FHPath::writeOut(librevenge::RVNGPropertyListVector&)` and reading the `"librevenge:path-action"` nodes.
- All higher-level records (`FHGroup`, `FHCompositePath`, `FHTextObject`, `FHImageImport`, `FHTileFill`, `FHPatternFill`) are plain data structs in `FHTypes.h`.

## Bridge Design

### Strategy: pure-C interface in `FreeHandBridge.h`, implemented in new `.mm`

- Use the existing pattern: C entrypoints, `extern "C"` block, C++ internals, `malloc/free` handoff.
- C wrapper gives Swift cleanly-typed pointers and stable ABI without Swift/C++ interop.
- New file lives in the same synchronized folder — no pbxproj change.

### FHCollector access: one public method + POD view struct

Add one public method `inkpenBuildView(InkpenCollectorView&)` on `FHCollector` that populates a POD struct with const references to the private maps. This is the smallest possible diff (~17 lines added across FHCollector.{h,cpp}).

`InkpenCollectorView` lives in a new header `ThirdParty/libfreehand/InkpenCollectorView.h` and holds const references to: `m_pageInfo`, `m_block`, `m_layers`, `m_lists`, `m_paths`, `m_groups`, `m_clipGroups`, `m_compositePaths`, `m_transforms`, `m_graphicStyles`, `m_propertyLists`, `m_basicFills`, `m_linearFills`, `m_radialFills`, `m_tileFills`, `m_patternFills`, `m_lensFills`, `m_basicLines`, `m_linePatterns`, `m_rgbColors`, `m_tints`, `m_multiColorLists`, `m_textObjects`, `m_displayTexts`, `m_paragraphs`, `m_paragraphProperties`, `m_charProperties`, `m_textBloks`, `m_tStrings`, `m_strings`, `m_fonts`, `m_images`, `m_dataLists`, `m_data`, `m_newBlends`, `m_symbolInstances`, `m_symbolClasses`, plus session token IDs `m_fillId`/`m_strokeId`/`m_contentId`.

### Data flow replacement

Current invocation (`VectorImportManager.swift` line 285): `FreeHandImporter.parseToSVG` → SVG string → `parseSVGContent` → shapes.

New invocation:
1. `FreeHandImporter.parseToShapes(url:)` reads the file.
2. Calls C entrypoint `freehand_parse_to_shapes(bytes, length, &out_handle)`.
3. `FreeHandDirectTranslator.mm`:
   - Builds `RVNGMemoryInputStream`, checks `FreeHandDocument::isSupported`.
   - Instantiates `libfreehand::FHCollector`, runs `FHParser::parse(input, &collector)`.
   - Calls `collector.inkpenBuildView(view)`.
   - Walks the view and fills a C-compatible result buffer.
   - Returns opaque `struct fh_result *`.
4. Swift walks the handle into `[VectorShape]` and calls `freehand_free_result`.
5. `VectorImportManager.importFreeHand` (~30 lines) calls `parseToShapes`, returns `VectorImportResult`.

### Coordinate space

FreeHand uses PostScript-style Y-up points (double). The collector's `_normalizePath` (FHCollector.cpp:535) flips Y and offsets so the final origin is top-left with Y growing downward:

```cpp
FHTransform trafo(1.0, 0.0, 0.0, -1.0, - m_pageInfo.m_minX, m_pageInfo.m_maxY);
```

This matches InkPen's convention. The translator uses the same normalization: object xform first, then stacked group xforms popped top-to-bottom, then normalization, then any `m_fakeTransforms`.

`FHTransform` uses (m11, m21, m12, m22, m13, m23) → CG `CGAffineTransform(a: m11, b: m21, c: m12, d: m22, tx: m13, ty: m23)`.

Page size: `m_pageInfo.m_maxX - m_pageInfo.m_minX` × `m_pageInfo.m_maxY - m_pageInfo.m_minY`.

### Style resolution

Fill/stroke resolved by walking `graphicStyleId`:
1. **FHPropList**: `m_parentId` (recursive) + `m_elements[m_fillId/m_strokeId/m_contentId]` where `m_fillId/m_strokeId/m_contentId` are session token IDs on the collector.
2. **FHGraphicStyle**: `m_parentId` + `m_elements` keyed by attribute-name IDs. Use `_findFillId`/`_findStrokeId` to reach terminal fill/stroke record IDs.

Terminal fill IDs resolve via `_findBasicFill` → solid, `_findLinearFill` → linear, `_findRadialFill` → radial, `_findLensFill` → lens, `_findTileFill` → tile, `_findPatternFill` → pattern, `_findCustomProc` → custom.

Colors: `_findRGBColor(id)` returns 16-bit RGB (divide by 65535). `_findTintColor(id)` for tints → `getRGBFromTint`.

Opacity: `FHFilterAttributeHolder::m_filterId` → `_findOpacityFilter`.

## Structure Mapping

| FH record | Collector map | InkPen representation |
|---|---|---|
| `FHPath` | `m_paths` | `VectorShape` with `path: VectorPath(elements:)`, `fillRule = .evenOdd` iff `FHPath::getEvenOdd()`, transform stack applied |
| `FHCompositePath` | `m_compositePaths` | Single `VectorShape` with `isCompoundPath = true`, elements concatenated from children |
| `FHGroup` | `m_groups` | Container `VectorShape` via `VectorShape.group(from:)`, children appended first then container with `memberIDs` |
| `FHGroup` (clip) | `m_clipGroups` | Same as Group but `isClippingGroup = true`, first child `isClippingPath = true` |
| `FHTextObject` | `m_textObjects` | `VectorShape` with `typography`, `textContent`, resolved from `m_tStringId` → paragraphs → textBloks |
| `FHDisplayText` | `m_displayTexts` | Same but inline `m_characters`/`m_charProps` |
| `FHImageImport` | `m_images` | `VectorShape` with `embeddedImageData`, raw bytes via `inkpenGetImageData(m_dataListId)`, MIME sniffed |
| `FHLinearFill` | `m_linearFills` | `FillStyle(gradient: .linear)`, stops from multiColorList, angle `90 - m_angle` |
| `FHRadialFill` | `m_radialFills` | `FillStyle(gradient: .radial)`, center `(m_cx, m_cy)` |
| `FHTileFill` | `m_tileFills` | Pre-resolved inline clip-group: host path as clip mask, tile subtree as children |
| `FHPatternFill` | `m_patternFills` | Solid fill from `m_colorId`, raw 8-byte pattern in metadata |
| `FHBasicLine` | `m_basicLines` | `StrokeStyle` with width, dash from `linePattern.m_dashes` |
| `FHNewBlend` | `m_newBlends` | Phase 4. Fallback: emit list1+list2+list3 as auto-group |
| `FHSymbolInstance` | `m_symbolInstances` | Recurse into `symbolClass.m_groupId`, full clone |

## Phase 1 — Scaffolding + plain paths

**Acceptance**: Open any supported FH file, every solid `FHPath` appears at the correct position with correct fill/stroke. Groups/text/images/gradients silently skipped.

### New files
1. `ThirdParty/libfreehand/InkpenCollectorView.h` (~60 lines)
2. `ThirdParty/libfreehand/FreeHandDirectTranslator.mm` (~350 lines)
3. `Utilities/FreeHand/FreeHandDirectImporter.swift` (~180 lines)

### Modified files
1. `ThirdParty/libfreehand/FreeHandBridge.h` (+10): new C entrypoints
2. `ThirdParty/libfreehand/FHCollector.h` (+2): include + public method declaration
3. `ThirdParty/libfreehand/FHCollector.cpp` (+15): `inkpenBuildView` implementation
4. `Utilities/Vector/VectorImportManager.swift` (-50/+40): switch `importFreeHand` to direct path

### Path geometry
Call `FHPath::writeOut(RVNGPropertyListVector&)` and iterate the `"librevenge:path-action"` entries (M/L/C/Q/A/Z) with `svg:x/y/x1/y1/x2/y2` keys. Arc elements flatten to cubic approximations.

### Feature flag
Keep the legacy SVG path alive behind a setting `useDirectFreeHandImporter` until Phase 4.

## Phase 2 — Structure

**Acceptance**: `FHGroup`, `FHClipGroup`, `FHCompositePath` become native containers. Transform stack works for nested groups.

### New helpers in `FreeHandDirectTranslator.mm`
- `walkGroup(const FHGroup*, Ctx&)` — push xform, recurse, emit container with `memberIDs`, pop
- `walkClipGroup(...)` — same but mark first child `isClippingPath`, container `isClippingGroup`
- `walkCompositePath(const FHCompositePath*, Ctx&)` — merge child paths, set `isCompoundPath`
- `walkSomething(unsigned id, Ctx&)` — dispatch (mirror `_outputSomething` at line 1012), carry `visitedObjects` for cycle safety

### Extend `InkpenCollectorView`
Add: `m_groups`, `m_clipGroups`, `m_compositePaths`.

## Phase 3 — Rich content

**Acceptance**: Text with correct font/size/color, raster images with real bytes, linear+radial gradients with correct stops, tile fills rendered once clipped to host bbox, pattern fills fall back to solid.

### Work
1. **Text**: resolve `m_tStringId` → paragraph list → `textBlok` (UTF-16) + char styles → one simplified `TypographyProperties` per object. Position/size/rotation from four-corner math in `_outputTextObject` lines 1348-1389.
2. **DisplayText**: simpler, inline `m_characters` + `m_charProps`.
3. **Image**: walk `_outputImageImport` (line 1946). Add public `inkpenGetImageData(unsigned)` on `FHCollector` forwarding to private `getImageData`. Sniff MIME with `isPng/isJpeg/isTiff/isBmp`. Four-corner rectangle for bounds.
4. **Linear gradient**: `FillStyle(gradient: .linear(stops, angle: 90 - m_angle))`. Stops from multiColorList or `(m_color1Id, m_color2Id)`.
5. **Radial gradient**: similar with center `(m_cx, m_cy)`.
6. **Tile fill**: recurse into `m_groupId` with scale/offset, emit as clip group with host path as mask.
7. **Pattern fill**: solid from `m_colorId`, hex-encoded 8-byte bitmap in metadata.

## Phase 4 — Cleanup

**Acceptance**: Old SVG pipeline deleted. FHCollector bitmap-fill hacks reverted. `.freehand` is a first-class `VectorFileFormat`.

### Delete
- `freehand_parse_to_svg`, `freehand_free_svg`, `stripUrlFills` from `FreeHandBridge.{h,mm}`
- `FreeHandImporter.swift`
- `VectorImportManager.dumpFreeHandSVG`
- Feature flag `useDirectFreeHandImporter`

### Revert in FHCollector.cpp
- `_outputPath` contentId → bitmap branch (lines 981-988)
- `_appendTileFill` nested-SVG branch (lines 2437-2472)
- `_appendPatternFill` DIB generation (lines 2481-2491)
- `_outputClipGroup` skip-first-element workaround (line 1070)

### Add
- `case freehand = "fh"` to `VectorFileFormat` mapped to FH3-FH11 extensions

## Risks

1. **FHNewBlend interpolation** — libfreehand doesn't actually interpolate; emit list1+list2+list3 auto-grouped (low risk)
2. **FHSymbolInstance cycles** — carry `visitedObjects` deque
3. **FHPathText curved text** — flat-positioned fallback for Phase 3; full support stretch for Phase 4
4. **FH3 vs FH11 record shape** — `FHCharProperties` vs `FH3CharProperties` branch; mirror libfreehand's branch
5. **Opacity filter holder chain** — walk holders exactly as `_appendFillProperties` (line 2155-2162)
6. **Transform ordering** — port the 25-line block from FHCollector.cpp:952-971 verbatim
7. **CMYK→RGB** — use `m_red/m_green/m_blue` precomputed by libfreehand's profile code
8. **Page bounds uninitialized** — fall back to `m_fhTail.m_pageInfo` (replicate line 1194)
9. **Xcode DerivedData staleness** — clean once after adding first new `.mm`

## Testing matrix

| Fixture | Phase | Observable |
|---|---|---|
| CrnkBait.FH7 | 1 | Every curve drawn; colors correct |
| painter.fh | 1 | Paths render (text deferred to Phase 3) |
| Nested-group logo | 2 | Container hierarchy in Layers panel |
| Photo-in-shape clip | 2+3 | Clip mask trims the image |
| Gradient swatchbook | 3 | Smooth gradients, correct angle |
| Text-dense brochure | 3 | Text editable with correct font |
| Pattern-filled map | 3 | Host path clipped to tile content |
| FH11 with symbols | 2+3 | Symbols cloned at instance sites |
