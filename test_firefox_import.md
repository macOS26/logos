# Firefox SVG Coordinate Conversion Test

## Original Coordinates (userSpaceOnUse)
- **radial-gradient**: cx="-7159.91" cy="-2133.76" r="823.26"
- **radial-gradient-2**: cx="-7465.58" cy="-2469.99" r="823.26"
- **radial-gradient-3**: cx="-7363.69" cy="-1950.36" r="596.36"

## ViewBox
- viewBox="0 0 1024 1024"
- viewBoxWidth = 1024
- viewBoxHeight = 1024

## Current Conversion Formula
```
objectBoundingBox = (userSpaceOnUse - boundingBoxOrigin) / boundingBoxDimension
```

## Expected Results (with current formula)
- **radial-gradient**: 
  - cx = (-7159.91 - 0) / 1024 = -6.99
  - cy = (-2133.76 - 0) / 1024 = -2.08
  - r = 823.26 / 1024 = 0.80

## Problem
The coordinates are negative and way outside the 0-1 range! This suggests the Firefox SVG uses a coordinate system that extends far beyond the viewBox.

## Possible Solutions
1. **Clamp coordinates to 0-1 range** after conversion
2. **Use the actual shape bounds** instead of viewBox
3. **Handle gradientTransform** before coordinate conversion
4. **Use a different reference coordinate system**

## Test Plan
Import the Firefox SVG and check the logs to see what coordinates are being generated. 