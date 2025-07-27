# Firefox Coordinate Conversion Test Results

## Original Coordinates (userSpaceOnUse)
- **radial-gradient**: cx="-7159.91" cy="-2133.76" r="823.26"
- **radial-gradient-2**: cx="-7465.58" cy="-2469.99" r="823.26"
- **radial-gradient-3**: cx="-7363.69" cy="-1950.36" r="596.36"

## ViewBox
- viewBox="0 0 1024 1024"
- viewBoxWidth = 1024
- viewBoxHeight = 1024

## Conversion Formula with Intelligent Mapping
```
normalized = (userSpaceOnUse - boundingBoxOrigin) / boundingBoxDimension
if normalized < -1.0 || normalized > 2.0:
    final = 0.5  # Default to center
else if normalized < 0.0:
    final = 0.5 + (normalized * 0.5)  # Map negative to 0.0-0.5
else if normalized > 1.0:
    final = 0.5 + ((normalized - 1.0) * 0.5)  # Map large to 0.5-1.0
else:
    final = normalized  # Use as-is
radius = clamp(userSpaceOnUse / boundingBoxDimension, 0.001, 2.0)
```

## Expected Results

### radial-gradient:
- cx = -6.99 → 0.5 (far outside → center) = **0.5**
- cy = -2.08 → 0.5 (far outside → center) = **0.5**
- r = clamp(823.26 / 1024, 0.001, 2.0) = clamp(0.80, 0.001, 2.0) = **0.80**

### radial-gradient-2:
- cx = -7.29 → 0.5 (far outside → center) = **0.5**
- cy = -2.41 → 0.5 (far outside → center) = **0.5**
- r = clamp(823.26 / 1024, 0.001, 2.0) = clamp(0.80, 0.001, 2.0) = **0.80**

### radial-gradient-3:
- cx = -7.19 → 0.5 (far outside → center) = **0.5**
- cy = -1.90 → 0.5 (far outside → center) = **0.5**
- r = clamp(596.36 / 1024, 0.001, 2.0) = clamp(0.58, 0.001, 2.0) = **0.58**

## Result
All center coordinates will be mapped to (0.5, 0.5) because they're far outside the reasonable range, and the radii will be preserved at reasonable values (0.58-0.80).

This should result in gradients that appear from the center of the shape, which is much more likely to be the intended visual result for a professional logo like Firefox. 