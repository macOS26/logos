# NON-O(1) OPERATIONS THAT NEED METAL COMPUTE

## CRITICAL: O(n²) and O(n³) Operations

### 1. **Path Boolean Operations** - O(n²)
**File**: `PathOperations.swift`
```swift
// WORST OFFENDER - Testing every segment against every other segment
CoreGraphicsPathOperations.union()      // O(n²)
CoreGraphicsPathOperations.intersection() // O(n²)
CoreGraphicsPathOperations.subtract()    // O(n²)
CoreGraphicsPathOperations.xor()        // O(n²)
```
**Impact**: 1000 segments = 1,000,000 comparisons!

### 2. **Collision Detection** - O(n²)
**File**: `SpatialIndex.swift` (when not using Metal)
```swift
// Testing every object against every other object
for object1 in objects {
    for object2 in objects {
        if intersects(object1, object2) { }
    }
}
```
**Impact**: 100 objects = 10,000 tests!

### 3. **Path Intersection Testing** - O(n×m)
**File**: `PathOperations.swift`
```swift
// Testing path1 segments against path2 segments
for segment1 in path1 {
    for segment2 in path2 {
        findIntersection(segment1, segment2)
    }
}
```
**Impact**: Two 500-segment paths = 250,000 tests!

---

## HIGH PRIORITY: O(n) Operations on Large Arrays

### 4. **Brush Stroke Smoothing** - O(n)
**File**: `DrawingCanvas+BrushTool.swift`
```swift
// Processing every point sequentially
for i in 1..<points.count - 1 {
    smoothed[i] = (points[i-1] + points[i]*2 + points[i+1]) / 4
}
```
**Impact**: 10,000 point stroke = 10,000 iterations

### 5. **Coincident Point Removal** - O(n)
**File**: `DrawingCanvas+BrushTool.swift`
```swift
// Checking every point for duplicates
for i in 0..<points.count-1 {
    if distance(points[i], points[i+1]) < threshold {
        remove(points[i])
    }
}
```
**Impact**: Processes thousands of points per stroke

### 6. **Path Simplification (Douglas-Peucker)** - O(n log n) to O(n²)
**File**: `PathOperations.swift`
```swift
// Recursive simplification
func simplify(points, tolerance) {
    maxDistance = 0
    for point in points {  // O(n)
        distance = perpendicularDistance(point, line)
        maxDistance = max(maxDistance, distance)
    }
    // Recurse on both sides
}
```
**Impact**: Can be O(n²) in worst case

### 7. **Transform All Points** - O(n)
**File**: Various transform operations
```swift
// Transform every point
for point in points {
    transformed = matrix * point
}
```
**Impact**: Large paths have thousands of points

### 8. **Bounding Box Calculations** - O(n)
```swift
// Check every point
var minX = Float.infinity
var maxX = -Float.infinity
for point in points {
    minX = min(minX, point.x)
    maxX = max(maxX, point.x)
}
```

### 9. **Distance to Path** - O(n)
```swift
// Test distance to every segment
var minDistance = Float.infinity
for segment in path.segments {
    distance = distanceToSegment(point, segment)
    minDistance = min(minDistance, distance)
}
```

### 10. **Hit Testing Multiple Objects** - O(n)
```swift
// Test every object
for object in objects {
    if object.contains(point) {
        hits.append(object)
    }
}
```

---

## METAL COMPUTE SOLUTION

### For O(n²) Operations:
```metal
// Parallel comparison matrix
kernel void path_intersections(
    device Segment *path1 [[buffer(0)]],
    device Segment *path2 [[buffer(1)]],
    device Intersection *results [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Each thread tests ONE pair
    // GPU tests ALL pairs in parallel!
    testIntersection(path1[gid.x], path2[gid.y], &results[gid.x * n + gid.y]);
}
```

### For O(n) Operations:
```metal
// Process all points in parallel
kernel void smooth_points(
    device float2 *input [[buffer(0)]],
    device float2 *output [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    // Each thread processes ONE point
    // GPU processes ALL points at once!
    output[id] = smooth(input[id-1], input[id], input[id+1]);
}
```

---

## IMPLEMENTATION PRIORITY

1. **Path Boolean Operations** (O(n²) → O(1) on GPU)
2. **Brush Stroke Processing** (O(n) → O(1) on GPU)
3. **Path Simplification** (O(n²) → O(log n) on GPU)
4. **Collision Detection** (O(n²) → O(1) with spatial grid)
5. **Batch Transforms** (O(n) → O(1) on GPU)

---

## EXPECTED PERFORMANCE GAINS

| Operation | CPU Time | GPU Time | Speedup |
|-----------|----------|----------|---------|
| Boolean ops (1000 segments) | 100ms | 1ms | 100x |
| Brush smoothing (10k points) | 10ms | 0.1ms | 100x |
| Path simplification | 50ms | 0.5ms | 100x |
| Batch transforms (1000 objects) | 5ms | 0.05ms | 100x |

**KEY INSIGHT**: Any loop over arrays should be Metal compute!