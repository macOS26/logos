# libfreehand C++ → Swift Staged Migration Plan

Written 2026-04-11. Snapshot of a conversation discussing how to move the FreeHand import codebase from C++ to Swift over time without breaking anything.

## Current architecture snapshot

The C++/Swift boundary is already at a sensible place. The cleanup passes we did earlier this session (Tier 1 + Tier 2) removed the entire SVG-debug surface — `FreeHandImporter.swift`, `dumpFreeHandSVG`, `freehand_parse_to_svg`/`freehand_free_svg`, `FreeHandDocument::parse(painter)`, `FHParser::parse(painter)`, `FHCollector::outputDrawing` — leaving only the direct data-walker path.

```
FH binary file
  ↓ C++: FHParser reads bytes → populates FHCollector's std::maps
  ↓ C++: FHCollector::inkpenBuildView exposes maps as const pointers via InkpenCollectorView
  ↓ Obj-C++: FreeHandDirectTranslator.mm walker reads the view, emits flat fh_result struct
  ↓ C bridge: freehand_parse_to_shapes / fh_result_* accessors
  ↓ Swift: FreeHandDirectImporter reads fh_result → builds [VectorShape]
  ↓ Swift: InkpenDocument / VectorImportManager installs shapes into a document
```

Everything above the walker (`FreeHandDirectImporter`, `InkpenDocument`, layer install) is already Swift. Everything below (`FHParser`, `FHCollector`, `FHPath`, `FHTransform`, `librevenge`) is still C++.

The staged migration pushes the C++/Swift line downward one piece at a time.

## Stage 0 — no change

Where we are today. The boundary is clean. The C bridge is the handoff point. No code changes needed to hold this position indefinitely. libfreehand keeps working for any FH version it already supports.

## Stage A — port the walker to Swift

**Scope.** `FreeHandDirectTranslator.mm` (~1200 lines) is nearly 100% logic that belongs in Swift:
- path-element iteration via `FHPath::writeOut` → property-list read
- `walkSomething`/`walkGroup`/`walkClipGroup`/`walkCompositePath`/`walkNewBlend`/`walkSymbolInstance` dispatch
- fill resolution (BasicFill, LinearFill, RadialFill, TileFill dominant-color fallback, PatternFill, LensFill)
- stroke resolution (BasicLine, PatternLine)
- color/tint math, RGBColor → VectorColor.rgb
- auto-fit translation (shift content so `minX,minY = 0,0`)
- clip-group leaf flattening
- unit scaling (FH inches → InkPen points via `FH_POINTS_PER_INCH`)
- walker stat counters

**Required change.** Expand the C bridge to expose `FHCollector`'s `std::map` iterators via small C-struct cursors:

- `fh_collector_path_count(col) -> size_t`
- `fh_collector_path_at(col, index, &out_fh_path) -> bool`
- `fh_collector_group_by_id(col, id, &out_fh_group) -> bool`
- equivalent accessors for all the record maps Swift needs
- A C-struct mirror of each FH record (`fh_group`, `fh_path_info`, `fh_linear_fill`, etc.) that Swift can read as a POD.

Swift then walks the trees directly via those accessors, builds `VectorShape` without an intermediate flat buffer.

**What stays C++.**
- `FHParser` (binary reader)
- `FHCollector` storage
- `FHPath::writeOut` for path element iteration (used by the Swift walker through a small cursor API)
- `FHTransform::applyToPoint`
- librevenge core types (internal to libfreehand)

**Risk.** Low. The walker lives in InkPen code and has clear test coverage via CrnkBait.FH7, painter.fh, clip-test.svg. Behavior is bit-identical — same walker logic in a different language.

**Effort.** ~1 week for someone already in the codebase.

**Payoff.**
- Swift-native debugging in the hot path (set breakpoints, use LLDB Swift mode, etc.)
- Easier to extend fill types (gradient stops, tile tiling, pattern bitmaps) in Swift
- No Obj-C++ translation unit in the build graph for the walker
- Establishes the migration pattern for later stages

**Stop point.** You can stop here and have a maintainable codebase indefinitely. The remaining C++ is stable reference code (parser + storage) that only needs touching when libfreehand has upstream fixes.

## Stage B — port `FHPath` + `FHTransform` to Swift

**Scope.**
- `FHPath` (path element sequence, `appendMoveTo`/`appendLineTo`/`appendCubicBezierTo`/`appendArcTo`/`appendClosePath`, transform application, writeOut)
- `FHTransform` (2D affine math via `m11/m21/m12/m22/m13/m23`, `applyToPoint`, `applyToArc`)

**Complication.** `FHParser` (still C++) builds `FHPath` instances during `readPath`, `readRectangle`, `readOval`, etc. If `FHPath` is ported to Swift, the C++ parser can't construct Swift `FHPath` values directly.

**Recommendation: do NOT do Stage B as a standalone step.** Either:
1. Skip it until Stage C (fold `FHPath`/`FHTransform` port into the parser port), or
2. Port `FHTransform` only (pure math, no parser coupling) — half-measure, limited payoff.

## Stage C — port `FHParser` to Swift

**Scope.** ~3000 lines of binary-format readers in `FHParser.cpp`. One reader per FH record type. 70+ record types, with variations per FH version (3, 5, 6, 7, 8, 9, 10, 11, MX).

**What Swift provides.**
- `Data` + `withUnsafeBytes` for binary reads with explicit byte order
- Swift enums for record-token dispatch (cleaner than giant switch statements)
- `try?` for graceful failure on malformed records
- Memory safety without `try/catch` bracketing

**Risk: high.** Bug-for-bug compatibility with libfreehand is what makes the current parser work. libfreehand has 15+ years of edge-case fixes per FH version. Re-implementing in Swift risks silent data loss per record type.

Specific gotchas:
- Per-version branches in almost every `readXxx` method (`if (m_version < 9) { ... } else { ... }`)
- Path coordinate decoding uses `1/72` scaling with fractional point precision
- Character encoding varies per FH version (UTF-16 vs. MacRoman vs. UTF-8)
- Some record types use chained pointers; the parser walks them via `m_visitedObjects` guard

**Mitigation plan.**
1. Port one record type at a time, smallest-dependency-first (e.g., `FHRGBColor`, `FHTransform`, `FHBasicFill` before `FHPath`, `FHGroup`, `FHTextObject`)
2. Keep the C++ parser running in parallel during the migration — run both on every test fixture, diff the resulting `FHCollector` maps
3. Promote a record type to "Swift-only" only after bit-for-bit parity on a broad fixture set
4. Build a test fixture corpus of 20-30 FH files spanning all versions before starting
5. CI that fails when the two parsers disagree on any record field

**Effort.** 2 months realistic for someone familiar with both C++ and Swift plus binary format work. Faster if the parity-testing harness is built first.

**Payoff.**
- ~3000 lines of C++ removed
- Swift-native binary reader — easy to debug, instrument, and extend
- FH format bugs become trivially fixable in Swift

## Stage D — port `FHCollector` data storage to Swift

**Scope.** `FHCollector`'s private `std::map<unsigned, FHGroup>`, `std::map<unsigned, FHPath>`, etc. become Swift `[UInt32: FHGroup]`, `[UInt32: FHPath]`.

**Precondition.** Only valuable after Stage C. The C++ parser writes to `std::map` via `collectXxx` methods. Swift storage means Swift `collect` methods and a Swift parser.

**Risk.** Medium — mostly mechanical, but ID-based references between maps (e.g., `FHGroup.m_elementsId` → `FHList.m_elements` → `FHPath`) need consistent integer types across all maps.

**Effort.** ~3 weeks after Stage C.

**Payoff.** No C++ in the FH import hot path. The only C++ left would be `librevenge` and `libfreehand_utils`.

## Stage E — replace `librevenge` core types

**Scope.** `RVNGPropertyList`, `RVNGString`, `RVNGBinaryData`, `RVNGInputStream`, `RVNGMemoryInputStream`, `RVNGStringVector`. Used by every `libfreehand` method.

After Stages C+D, librevenge is only used internally by whatever is still in C++ (none, if C and D are complete). At that point it's fully deletable.

**Recommendation.** Leave librevenge alone. It's ~10k lines of stable code that "just works." The cost of deleting it is low-value busywork. Better to keep it as a dependency and treat it as immutable.

## What to actually do next

**Only Stage A is worth starting in the short term.** It gives:
- Swift-native walker (where all the InkPen-specific logic lives)
- Clean boundary that's trivial to test (same CrnkBait.FH7 / clip-test.svg fixtures)
- Zero risk to the binary reader (Stage C's hard part)
- You can stop after Stage A and have a maintainable codebase for years

Stages C and D together are a quarter-scale project that needs dedicated effort, parallel-parser testing infrastructure, and should only be attempted when the app is otherwise stable.

## Files touched by each stage

### Stage A
- **Expand**: `logos inkpen.io/ThirdParty/libfreehand/FreeHandBridge.h` — add map iterator C functions
- **Expand**: `logos inkpen.io/ThirdParty/libfreehand/FreeHandBridge.mm` — implement the iterators by calling `FHCollector::inkpenBuildView` + returning struct views
- **Delete**: `logos inkpen.io/ThirdParty/libfreehand/FreeHandDirectTranslator.mm` (entire file)
- **New**: `logos inkpen.io/Utilities/FreeHand/FreeHandWalker.swift` — Swift port of the walker
- **Modify**: `logos inkpen.io/Utilities/FreeHand/FreeHandDirectImporter.swift` — call the Swift walker instead of the C bridge's `freehand_parse_to_shapes`

### Stage C (when it happens)
- **Expand**: `logos inkpen.io/ThirdParty/libfreehand/FreeHandBridge.h` — add a dual-parser verification entrypoint (takes a file, runs both parsers, returns diff)
- **New**: `logos inkpen.io/Utilities/FreeHand/FHParserSwift.swift` — Swift binary reader
- **New**: `logos inkpen.io/Utilities/FreeHand/FHCollectorSwift.swift` — Swift collector (if doing C+D together)
- **Expand**: test harness with 20-30 FH fixtures spanning all versions
- **Eventually delete**: `FHParser.cpp`, `FHParser.h`, `FHCollector.cpp`, `FHCollector.h`

## Context from this session

This plan was authored after an 8+ hour session that took the FreeHand import from the old `libfreehand → SVG → SVGParser` round-trip to a direct walker that reads `FHCollector`'s private maps and emits native `VectorShape` / `isClippingGroup` / gradient fills. The direct translator handles:
- Paths, groups, clip groups, composite paths
- Linear and radial gradients with proper stops and angles
- Solid-color fallback for tile/pattern/lens fills
- NewBlend and SymbolInstance walker support
- Flat clip-group member resolution (clip groups only contain leaf paths, never nested groups)
- Auto-fit translation for content that sits outside the FH page bounds
- Unit conversion (FH inches → InkPen points)
- FH3 page-info fallback via `fhTail.m_pageInfo`

The Swift side handles:
- Native Clipping Group containers (`isClippingGroup=true`, memberIDs positional with mask at 0)
- Simple geometric shape detection (Rectangle, Square, Circle, Ellipse, Triangle, Pentagon, Hexagon, Heptagon, Octagon)
- "Clip Path" / "Masked Path" naming to match hand-made clipping groups
- File → Open of FH files (`InkpenDocument.readableContentTypes` + FH-magic-byte sniff)
- File → Import continues to work alongside File → Open

All the painter-side helpers in `FHCollector.cpp` (`_output*`, `_append*Fill`, `_getBBof*`, `_normalizePath`, `_generateBitmapFromPattern`) remain as in-source reference for Phase 3 work (proper tile tiling, pattern bitmap rendering). They're unreferenced but valuable documentation for how libfreehand handles complex fill types.
