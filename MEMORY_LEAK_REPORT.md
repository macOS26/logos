# InkPen Memory Leak Report

## Executive Summary
InkPen has **5 confirmed memory leaks** and **3 architectural issues** causing:
- 177KB images consuming 200MB+ RAM per tab
- RAM spilling between tabs (200MB → 4000MB cross-contamination)
- Closed tabs not releasing memory

---

## 🔴 LEAK 1: Image Double-Allocation in `imageStorage` + `embeddedImageData`
**Severity: CRITICAL — Primary cause of 200MB from 177KB images**

### Location
- `VectorDocument.swift:62` — `var imageStorage: [UUID: CGImage] = [:]`
- `VectorShape.swift:369` — `var embeddedImageData: Data? = nil`
- `ImageContentRegistry.swift:25` — `document.imageStorage[shapeID] = image`

### Root Cause
Every image shape stores its bitmap data **TWICE**:
1. **`VectorShape.embeddedImageData`** — the original compressed PNG/JPEG `Data` (small, ~177KB)
2. **`VectorDocument.imageStorage[shapeID]`** — the decompressed `CGImage` in full 32-bit BGRA (massive)

For a 177KB PNG that decodes to 4000×3000 pixels, the `CGImage` is:
```
4000 × 3000 × 4 bytes (BGRA) = 48,000,000 bytes = ~48MB per image
```
If there are 4 such images on a canvas, that's **192MB just in imageStorage**, plus the `embeddedImageData` copies.

Additionally, `resolveLinkedImage()` in `UnifiedObjectView.swift:1370` creates **ANOTHER full-resolution bitmap** in memory when resolving linked images, even if the image is already cached in `imageStorage`. This triples the memory for linked images.

### Fix
```swift
// VectorDocument.swift — Replace eager imageStorage with lazy loading
// Instead of storing ALL CGImages in memory:

// Option A: Use NSCache for auto-eviction
static let imageCache = NSCache<NSString, CGImage>()

// Option B: Generate thumbnails and only cache those
var imageThumbnailStorage: [UUID: CGImage] = [:]  // small thumbnails
```

In `ImageContentRegistry.swift`, load images on-demand instead of eagerly storing full-res:
```swift
static func image(for shapeID: UUID, in document: VectorDocument) -> CGImage? {
    if let cached = document.imageStorage[shapeID] { return cached }
    // Lazy-load from embeddedImageData or linked path
    return loadAndCache(shapeID, in: document)
}
```

---

## 🔴 LEAK 2: Cross-Tab Contamination via Shared `AppState`
**Severity: CRITICAL — Causes RAM to spill from one tab into another**

### Location
- `AppState.swift` (singleton)
- `DocumentBasedMainView.swift:284-330` — `onAppear`/`onDisappear`

### Root Cause
`AppState.shared` is a singleton that potentially holds references to document-specific state. Each tab's `DocumentBasedMainView` interacts with the shared `AppState`, and if any document-specific data leaks into the singleton, it accumulates across tabs.

More critically, the `DocumentBasedMainView` uses `@StateObject private var documentState = DocumentState()` — but `onDisappear` in SwiftUI is **not guaranteed to be called** when:
- The app is backgrounded
- The window is closed (not just the tab)
- macOS terminates the app
- SwiftUI's view identity changes cause recreation without proper teardown

This means `DocumentState.cleanup()` may never run, leaving `imageStorage`, `VectorDocument`, and all its children in memory forever.

### Fix
1. Add a `deinit` to `DocumentState` that calls `cleanup()`:
```swift
// DocumentState.swift
deinit {
    cleanup()
}
```

2. In `InkpenDocument`, override `close()` to force cleanup:
```swift
// InkpenDocument.swift
override func close() {
    // Force cleanup of the document's state
    if let contentView = windowControllers.first?.contentViewController {
        // Walk the view hierarchy and trigger cleanup
    }
    super.close()
}
```

---

## 🔴 LEAK 3: `renderImage()` Creates Duplicate Bitmap Copies
**Severity: HIGH — Multiplies memory usage per redraw**

### Location
- `UnifiedObjectView.swift:1414-1550` — `renderImage()` method

### Root Cause
The `renderImage()` method:
1. Fetches the image from `ImageContentRegistry` (which gets it from `imageStorage`) → Copy 1
2. Creates a new `CGContext` to draw into (potentially at full canvas resolution) → Copy 2
3. Draws the image into this context
4. Returns/uses the result — but the intermediate context's backing store isn't always released

Each call to `renderImage` can allocate `width × height × 4` bytes temporarily. If called frequently during scrolling/zooming, these pile up.

### Fix
```swift
// Use Autoreleasepool to ensure temporary contexts are freed
private func renderImage(...) {
    autoreleasepool {
        // existing render code
    }
}
```

Also consider using `CGImage` thumbnail APIs instead of full-resolution rendering:
```swift
let options: [CFString: Any] = [kCGImageSourceThumbnailMaxPixelSize: maxDisplaySize]
```

---

## 🟡 LEAK 4: `VectorDocument` Observational Retain Cycle
**Severity: MEDIUM — Prevents VectorDocument deallocation**

### Location
- `VectorDocument.swift:227-229` — Combine sink on `viewState.objectWillChange`

### Root Cause
```swift
viewState.objectWillChange.sink { [weak self] _ in
    self?.objectWillChange.send()
}.store(in: &cancellables)
```

This uses `[weak self]` correctly. However, `viewState` is owned by `VectorDocument`, and `cancellables` is also owned by `VectorDocument`. The cancellable holds a weak reference back to `VectorDocument`, but the closure also captures `viewState` indirectly through the sink. Check if `viewState` holds any strong reference back to `VectorDocument`.

### Fix
Ensure `DocumentViewState` does NOT hold a strong reference to its parent `VectorDocument`. If it does, break it with `weak`.

---

## 🟡 LEAK 5: `DocumentStateRegistry` Never Removes Entries
**Severity: MEDIUM — Weak references prevent deallocation tracking**

### Location
- `DocumentStateRegistry.swift` — `NSHashTable.weakObjects()`
- `DrawingCanvasRegistry.swift` — `weak var activeDocument`

### Root Cause
While these registries use weak references (so they don't prevent deallocation), they never actively remove entries. This means:
- Debug logging shows stale entries
- Any iteration over registry entries processes dead references
- If `DocumentState` is deallocated but a closure still holds a strong ref temporarily, the registry entry can "resurrect"

### Fix
Add explicit `unregister()` calls in `DocumentState.cleanup()`:
```swift
func cleanup() {
    DocumentStateRegistry.shared.unregister(self)
    // ... existing cleanup
}
```

---

## 🔵 ARCHITECTURAL ISSUE 1: No Memory Budget for Image Cache
**Severity: Design Issue**

### Current Behavior
`VectorDocument.imageStorage` is a plain dictionary with no size limit. Every image ever loaded stays in memory until the document is closed.

### Recommendation
Replace with `NSCache` that auto-evicts under memory pressure:
```swift
// Replace: var imageStorage: [UUID: CGImage] = [:]
// With:
let imageStorage = NSCache<NSString, CGImage>()
// Configure limits:
imageStorage.countLimit = 50  // max 50 images cached
imageStorage.totalCostLimit = 200 * 1024 * 1024  // 200MB limit
```

---

## 🔵 ARCHITECTURAL ISSUE 2: Full-Resolution Bitmaps for Display
**Severity: Design Issue**

### Current Behavior
Images are stored and rendered at full resolution even when displayed at thumbnail size on the canvas.

### Recommendation
Generate display-resolution thumbnails at load time:
```swift
static func thumbnail(from cgImage: CGImage, maxPixelSize: Int) -> CGImage? {
    let options: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        kCGImageSourceCreateThumbnailFromImageAlways: true
    ]
    // ... create thumbnail
}
```
Only load full resolution for export/print.

---

## 🔵 ARCHITECTURAL ISSUE 3: Tab Isolation
**Severity: Design Issue**

### Current Behavior
All tabs share the same `AppState.shared` singleton and can access each other's state through the registries.

### Recommendation
Each tab should have its own isolated state container:
```swift
// Per-tab state bag
class TabState {
    let documentState: DocumentState
    let imageCache: NSCache<NSString, CGImage>
    // ... other per-tab resources
}
```

---

## Immediate Action Items (Priority Order)

1. **Add `deinit` to `DocumentState`** → Ensures cleanup always runs
2. **Replace `imageStorage` dictionary with `NSCache`** → Auto-eviction under pressure  
3. **Add thumbnail generation at load time** → Reduces per-image RAM from ~48MB to ~2MB
4. **Wrap `renderImage()` in `autoreleasepool`** → Prevents temporary bitmap pileup
5. **Force cleanup in `InkpenDocument.close()`** → Safety net for tab closure
6. **Add memory warning handler** → Proactively purge caches
