# Metal Compute Shader Opportunities

## Currently Using Metal Compute Shaders

### 1. **MetalSpatialIndex**
- `build_spatial_index` - Building spatial index grid
- `query_point` - Point queries in spatial index
- `query_rect` - Rectangle queries
- `clear_grid` - Clearing spatial grid

### 2. **MetalComputeEngine** (Many pipelines defined but usage unclear)
- Douglas-Peucker path simplification
- Bezier curve calculations
- Matrix transformations
- Collision detection
- Path rendering
- Vector operations (distance, normalize, lerp)
- Handle calculations
- Curvature calculations
- Chaikin smoothing
- Distance calculations
- Trigonometric operations
- Boolean geometry
- Path intersections
- Nearest point/handle finding
- Path hit testing
- Snap point finding

### 3. **PDF Processing**
- `transformPoints` - Transform multiple points
- `batchTransformPoints` - Batch point transformations
- `multiplyMatrices` - Matrix multiplication
- `calculateBounds` - Bounding box calculations
- `mergeBounds` - Merging multiple bounds
- `batchCalculateDistances` - Distance calculations
- `perpendicularDistances` - Perpendicular distance to line
- `evaluateCubicBezier` - Bezier evaluation
- `calculateCurveFlatness` - Curve flatness testing
- `batchCheckCollinearity` - Collinearity checks
- `batchRectIntersections` - Rectangle intersections
- `parallelMax` - Finding maximum values
- `batchInterpolate` - Interpolation operations

## New Opportunities for Metal Compute Shaders

### 1. **Path Operations** (PathOperations.swift)
- **Path simplification** - Currently using loops for Douglas-Peucker
- **Path intersection** - Complex O(n²) operations
- **Boolean operations** (union, difference, intersection)
- **Path offsetting/stroking** - Parallel offset calculations
- **Path tessellation** - Converting curves to line segments

### 2. **Brush Tool** (DrawingCanvas+BrushTool.swift)
- **Stroke smoothing** - Processing arrays of points
- **Pressure interpolation** - Smoothing pressure values
- **Stroke tapering** - Applying taper to stroke points
- **Coincident point removal** - Finding and removing duplicates

### 3. **Corner Radius Tool**
- **Mass corner radius updates** - Updating multiple corners at once
- **Arc calculations** - Computing arc points for rounded corners

### 4. **Image Processing** (MetalImageTileRenderer.swift)
- **Image downsampling** - Already has some Metal but could expand
- **Tile generation** - Parallel tile processing
- **Mipmap generation** - Level-of-detail processing

### 5. **Spatial Operations**
- **Batch hit testing** - Testing multiple points against paths
- **Mass selection** - Selecting objects in regions
- **Proximity queries** - Finding nearby objects

### 6. **Transform Operations**
- **Batch transformations** - Transforming multiple objects
- **Matrix concatenation** - Combining transform matrices
- **Inverse transforms** - Computing inverse matrices

### 7. **Color Operations**
- **Color space conversion** - RGB↔HSL, RGB↔CMYK
- **Gradient interpolation** - Computing gradient colors
- **Color matching** - Finding similar colors

### 8. **Text Operations**
- **Glyph outline generation** - Converting text to paths
- **Text layout calculations** - Computing text positions
- **Kerning/spacing** - Adjusting character spacing

### 9. **Export Operations**
- **PNG rendering** - Parallel pixel processing
- **SVG path optimization** - Simplifying paths for export
- **PDF content stream generation** - Parallel command generation

### 10. **Undo/Redo Operations**
- **Diff calculations** - Computing differences between states
- **State compression** - Compressing undo states

## High-Priority Targets

Based on performance impact and frequency of use:

1. **Brush stroke processing** - Used constantly during drawing
2. **Path boolean operations** - Complex and slow on CPU
3. **Spatial queries** - Already partially implemented
4. **Image downsampling** - Heavy operation for large images
5. **Export rendering** - One-time but heavy operations

## Implementation Strategy

1. **Profile first** - Measure current CPU performance
2. **Batch operations** - Group similar operations together
3. **Async processing** - Don't block UI thread
4. **Fallback to CPU** - Always have CPU implementation
5. **Cache results** - Reuse computed values

## Code Example: Brush Smoothing

Current CPU code:
```swift
// O(n) iterations
for i in 1..<points.count - 1 {
    smoothed[i] = (points[i-1] + points[i] * 2 + points[i+1]) / 4
}
```

Metal compute shader:
```metal
kernel void smooth_points(
    device float2 *input [[buffer(0)]],
    device float2 *output [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    if (id == 0 || id >= count - 1) {
        output[id] = input[id];
    } else {
        output[id] = (input[id-1] + input[id] * 2.0 + input[id+1]) * 0.25;
    }
}
```

This would process all points in parallel on GPU!