# Release Notes

## 1.0.5

### FreeHand 2 (FHD2) Import — Major New Feature
- **Native FreeHand 2 binary parser** — reverse-engineered from scratch to import legacy `.fh` files from the FHD2 format
- Rectangle, line, and oval/ellipse shape support
- Bézier curve and closed path rendering
- Fill, stroke, stroke width, and grayscale decoding
- CMYK color table support with full color engine
- Radial and linear gradient fill support with center/radius from file data
- Layer detection and absolute ID tracking
- Magic byte detection for File → Open auto-detection

### FreeHand EPS Import
- New **PostScript/EPS parser** with `.eps` File → Open support
- PostScript concat transform matrix support

### FreeHand 3+ Fixes
- Fixed clipping group rendering for FH3+ files by restoring `installGroupMemberIntoSnapshot` import path

### Performance & Memory
- **~60–80 MB idle RAM reduction** — shared Metal device, stripped unused GPU resources, released singletons
- Lazy-load and release SF Symbols cache (~15–25 MB) and Pantone library (~1 MB)
- Share font caches across documents
- Use `SharedMetalDevice` in `MetalSpatialIndex`

### UI Improvements
- SF Symbols picker now shows empty state or recents instead of loading all 6,000+ symbols at once
- Guard against array bounds crashes in LayersPanel color swatch and layer row views
- Disabled window state restoration to prevent duplicate windows on relaunch
- Fixed window flash on launch — frame set synchronously with `display: false`
- Fixed blank window race condition — tabs start active instead of suspended

---

## 1.0.4

### FreeHand 2 Parser (Initial)
- First batch of FH2 format support: point data, record scanning, bounding boxes
- Fill and stroke decoding with color chain lookups
- Sequential numbering and offset fixes

### Color System
- Isolated `0x1454` gradient colors from main color table to prevent yellow color pollution
- Fixed red color rendering without side effects on other colors

### Window Handling
- Disabled macOS window state restoration (`NSQuitAlwaysKeepsWindows`) to prevent stale state
- Fixed window flash on startup

---

## 1.0.3

### Performance
- **Tab suspension** — background tabs drop their view tree, cutting memory usage ~50%

### Documentation
- README updated with Performance & Memory section
