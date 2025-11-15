# Metal Compute Shader Analysis

## Section 1: WHAT WE HAVE NOW

### A. Spatial Index (WORKING)
**File**: `MetalSpatialIndex.swift`
```
✅ build_spatial_index - Building grid
✅ query_point - Finding objects at point
✅ query_rect - Finding objects in rectangle
✅ clear_grid - Clearing the grid
```

### B. PDF Operations (WORKING)
**File**: `PDFComputeShaders.metal`
```
✅ transformPoints - Transform arrays of points
✅ calculateBounds - Get bounding boxes
✅ batchCalculateDistances - Distance calculations
✅ evaluateCubicBezier - Bezier math
```

### C. General Compute Engine (DEFINED BUT NOT USED)
**File**: `MetalComputeEngine.swift`
```
⚠️ douglasPeuckerPipeline - Path simplification
⚠️ bezierCalculationPipeline - Bezier curves
⚠️ matrixTransformPipeline - Transforms
⚠️ pathIntersectionPipeline - Intersections
⚠️ findNearestPointPipeline - Nearest point
```

---

## Section 2: WHERE WE NEED METAL COMPUTE

### A. BRUSH STROKES (High Priority)

**Current Problem**: Processing points one by one in loops
**File**: `DrawingCanvas+BrushTool.swift`

```swift
// CURRENT SLOW CODE:
for i in 0..<points.count {
    smoothedPoints[i] = smooth(points[i])  // One at a time
}
```

**What needs Metal:**
- Point smoothing (Chaikin, Catmull-Rom)
- Pressure interpolation
- Coincident point removal
- Stroke tapering

### B. PATH OPERATIONS (High Priority)

**Current Problem**: O(n²) algorithms on CPU
**File**: `PathOperations.swift`

**What needs Metal:**
- Boolean operations (union, intersection, difference)
- Path simplification (Douglas-Peucker)
- Path offsetting/stroking
- Path intersection testing

### C. BATCH TRANSFORMATIONS (Medium Priority)

**Current Problem**: Transforming objects one by one
**Files**: Various transform operations

**What needs Metal:**
- Transform multiple shapes at once
- Apply matrix to point arrays
- Calculate inverse transforms
- Concatenate transform matrices

---

## Section 3: IMPLEMENTATION PLAN

### Phase 1: Brush Strokes (DO THIS FIRST)
```metal
// NEW: Process all points in parallel
kernel void smooth_stroke_points(
    device float2 *points [[buffer(0)]],
    device float2 *smoothed [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    // Smooth all points at once on GPU
}
```

### Phase 2: Path Operations
```metal
// NEW: Parallel path simplification
kernel void simplify_path(
    device float2 *input [[buffer(0)]],
    device bool *keep [[buffer(1)]],
    constant float &tolerance [[buffer(2)]]
) {
    // Test all points in parallel
}
```

### Phase 3: Batch Operations
```metal
// NEW: Transform many points at once
kernel void batch_transform(
    device float2 *points [[buffer(0)]],
    constant float3x3 &matrix [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    // Transform all points in parallel
}
```

---

## Section 4: SPECIFIC IMPLEMENTATIONS NEEDED

### 1. Brush Smoothing
**File to modify**: `DrawingCanvas+BrushTool.swift`
**Function**: `smoothBrushStroke()`
**Benefit**: 10-100x faster stroke smoothing

### 2. Coincident Point Removal
**File to modify**: `DrawingCanvas+BrushTool.swift`
**Function**: `removeCoincidentPoints()`
**Benefit**: Instant duplicate removal

### 3. Path Boolean Operations
**File to modify**: `PathOperations.swift`
**Functions**: `union()`, `intersection()`, `difference()`
**Benefit**: Complex operations in milliseconds

### 4. Batch Selection Testing
**File to modify**: `SpatialIndex.swift`
**Function**: `objectsInRect()`
**Benefit**: Test thousands of objects at once

### 5. Export Rendering
**File to modify**: `FileOperations+ExportToPNG.swift`
**Function**: `exportToPNG()`
**Benefit**: Parallel pixel processing

---

## Section 5: WHAT NOT TO DO

❌ Don't use Metal compute for:
- Single point operations
- Small arrays (< 100 elements)
- UI rendering (use SwiftUI/CoreGraphics)
- Simple math (overhead not worth it)

✅ DO use Metal compute for:
- Arrays with 1000+ elements
- Parallel mathematical operations
- Image processing
- Spatial queries
- Path processing

---

## Section 6: NEXT STEPS

1. Start with brush smoothing (most impact)
2. Add Metal compute to `smoothBrushStroke()`
3. Measure performance improvement
4. Move to path operations
5. Then batch transformations