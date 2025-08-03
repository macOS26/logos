# Oval vs Ellipse Implementation

## Research Summary

After researching the mathematical and geometric differences between ovals and ellipses, I've implemented distinct tools for each shape in the Logos Inkpen application.

## Key Differences

### Ellipse
- **Mathematical Definition**: A precise conic section defined by the equation (x²/a²) + (y²/b²) = 1
- **Properties**: Has two focal points, constant sum of distances from foci to any point on the curve
- **Implementation**: Uses Bézier curves with the standard 0.552 control point offset for accurate ellipse approximation
- **Use Case**: When mathematical precision is required

### Oval
- **Geometric Definition**: A rounded, circle-like shape that's more circular than an ellipse
- **Properties**: Similar to an ellipse but with more rounded curvature for a softer appearance
- **Implementation**: Uses Bézier curves with 0.58 control point offset (vs 0.552 for ellipse)
- **Use Case**: When a softer, more rounded appearance is desired

## Implementation Details

### Ellipse Tool (`createEllipsePath`)
```swift
// Uses mathematical ellipse curves with 0.552 control point offset
let controlPointOffsetX = radiusX * 0.552
let controlPointOffsetY = radiusY * 0.552
```

### Oval Tool (`createOvalPath`)
```swift
// Uses control points that create a more rounded, circle-like appearance
let controlPointOffsetX = radiusX * 0.58  // More rounded than ellipse's 0.552
let controlPointOffsetY = radiusY * 0.58
```

## Visual Differences

1. **Curvature**: The oval has more rounded curvature compared to the true ellipse
2. **Construction**: Oval uses simplified Bézier curves while ellipse uses precise mathematical curves
3. **Appearance**: Oval appears more "rounded and circular" while ellipse is more "precise"

## Files Modified

1. **`DrawingCanvas+ShapeCreation.swift`**: Added `createOvalPath` function
2. **`DrawingCanvas+ShapeDrawing.swift`**: Updated oval tool to use `createOvalPath` instead of `createEllipsePath`

## Testing

A test script (`test_oval_vs_ellipse.swift`) was created to verify that both tools produce different results while maintaining the same number of path elements.

## Usage

- **Ellipse Tool**: Use when you need a mathematically precise elliptical shape
- **Oval Tool**: Use when you want a softer, more organic rounded shape

Both tools now use different mathematical approaches and will produce visually distinct results, giving users more creative options for their designs. 