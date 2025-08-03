# Egg Shape Implementation

## Research Summary

After researching mathematical formulas for egg shapes, I've implemented a new egg tool that creates authentic chicken egg shapes using a modified ellipse approach with asymmetric radii.

## Mathematical Formula

The egg shape uses a **modified ellipse formula** with different radii for the top and bottom halves:

### Key Parameters:
- **Egg Factor**: 0.3 (controls the asymmetry)
- **Top Radius**: 70% of original radius (narrower)
- **Bottom Radius**: 115% of original radius (wider)

### Formula:
```swift
let eggFactor = 0.3
let topRadiusX = radiusX * (1.0 - eggFactor)      // 70% of original
let topRadiusY = radiusY * (1.0 - eggFactor)      // 70% of original
let bottomRadiusX = radiusX * (1.0 + eggFactor * 0.5)  // 115% of original
let bottomRadiusY = radiusY * (1.0 + eggFactor * 0.5)  // 115% of original
```

## Implementation Details

### Egg Tool (`createEggPath`)
```swift
// Egg shape parameters: wider at bottom, narrower at top
let eggFactor = 0.3  // Controls the egg asymmetry
let topRadiusX = radiusX * (1.0 - eggFactor)
let topRadiusY = radiusY * (1.0 - eggFactor)
let bottomRadiusX = radiusX * (1.0 + eggFactor * 0.5)
let bottomRadiusY = radiusY * (1.0 + eggFactor * 0.5)
```

## Visual Characteristics

1. **Asymmetry**: The egg is wider at the bottom and narrower at the top
2. **Natural Shape**: Mimics the characteristic chicken egg profile
3. **Smooth Curves**: Uses Bézier curves for smooth, natural appearance
4. **Scalable**: Works with any rectangle dimensions

## Comparison with Other Shapes

| Shape | Control Points | Characteristics |
|-------|---------------|-----------------|
| **Ellipse** | 0.552 | Mathematical precision, symmetric |
| **Oval** | 0.58 | Rounded, circle-like |
| **Egg** | 0.552 (asymmetric) | Natural egg shape, asymmetric |

## Files Modified

1. **`VerticalToolbar.swift`**: Added egg to CircleVariant enum and tool groups
2. **`VectorDocument.swift`**: Added egg to DrawingTool enum with icon and cursor
3. **`DrawingCanvas+ShapeCreation.swift`**: Added `createEggPath` function
4. **`DrawingCanvas+ShapeDrawing.swift`**: Added egg case to shape drawing
5. **`DrawingCanvas+UnifiedGestures.swift`**: Added egg to gesture handling

## Usage

- **Egg Tool**: Use when you need a natural, asymmetric egg shape
- **Best Results**: Works best with tall rectangles (height > width)
- **Applications**: Perfect for illustrations, logos, and organic designs

## Technical Notes

- Uses the same 4-curve Bézier structure as ellipse and oval
- Maintains smooth continuity between top and bottom curves
- Preserves the mathematical precision of the ellipse formula
- Creates authentic chicken egg proportions

The egg shape provides a unique organic option alongside the mathematical ellipse and rounded oval, giving users more creative possibilities for their designs. 