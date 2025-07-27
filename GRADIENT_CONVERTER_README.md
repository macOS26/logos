# SVG Radial Gradient Coordinate Converter

A Swift-based tool for converting radial gradient coordinates between `objectBoundingBox` and `userSpaceOnUse` coordinate systems in SVG files.

## Overview

This tool helps convert radial gradients in SVG files between two coordinate systems:

- **objectBoundingBox**: Coordinates are relative to the bounding box of the element (0.0 to 1.0)
- **userSpaceOnUse**: Coordinates are in the user coordinate system (absolute pixel values)

## Files Created

1. **`GradientCoordinateConverter.swift`** - Main Swift utility class (integrated into the Xcode project)
2. **`simple_converter.swift`** - Standalone Swift converter tool
3. **`convert_gradients.sh`** - Shell script wrapper for easy command-line usage
4. **`test_boundingbox_gradient.svg`** - Test file with objectBoundingBox coordinates
5. **`test_userspace_gradient.svg`** - Test file with userSpaceOnUse coordinates

## Usage

### Shell Script (Recommended)

```bash
# Convert from objectBoundingBox to userSpaceOnUse
./convert_gradients.sh input.svg output.svg

# Convert from userSpaceOnUse to objectBoundingBox
./convert_gradients.sh input.svg output.svg --reverse

# Show help
./convert_gradients.sh --help
```

### Direct Swift Usage

```bash
# Convert from objectBoundingBox to userSpaceOnUse
swift simple_converter.swift input.svg output.svg

# Convert from userSpaceOnUse to objectBoundingBox
swift simple_converter.swift input.svg output.svg --reverse
```

## Examples

### Input SVG with objectBoundingBox coordinates:
```svg
<svg viewBox="0 0 300 300">
  <defs>
    <radialGradient id="MyGradient" gradientUnits="objectBoundingBox"
                    cx="0.3" cy="0.4" r="0.3" fx="0.1" fy="0.2">
      <stop offset="0%" stop-color="red" />
      <stop offset="50%" stop-color="blue" />
      <stop offset="100%" stop-color="black" />
    </radialGradient>
  </defs>
  <rect fill="url(#MyGradient)" stroke="black" stroke-width="5"  
        x="50" y="100" width="200" height="200"/>
</svg>
```

### Output SVG with userSpaceOnUse coordinates:
```svg
<svg viewBox="0 0 300 300">
  <defs>
    <radialGradient id="MyGradient" gradientUnits="userSpaceOnUse" 
                    cx="90.0" cy="120.0" r="90.0" fx="30.0" fy="60.0">
      <stop offset="0%" stop-color="red" />
      <stop offset="50%" stop-color="blue" />
      <stop offset="100%" stop-color="black" />
    </radialGradient>
  </defs>
  <rect fill="url(#MyGradient)" stroke="black" stroke-width="5"  
        x="50" y="100" width="200" height="200"/>
</svg>
```

## Conversion Formulas

### objectBoundingBox to userSpaceOnUse:
- `cx_user = boundingBox.x + (cx_bbox * boundingBox.width)`
- `cy_user = boundingBox.y + (cy_bbox * boundingBox.height)`
- `r_user = r_bbox * min(boundingBox.width, boundingBox.height)`
- `fx_user = boundingBox.x + (fx_bbox * boundingBox.width)`
- `fy_user = boundingBox.y + (fy_bbox * boundingBox.height)`

### userSpaceOnUse to objectBoundingBox:
- `cx_bbox = (cx_user - boundingBox.x) / boundingBox.width`
- `cy_bbox = (cy_user - boundingBox.y) / boundingBox.height`
- `r_bbox = r_user / min(boundingBox.width, boundingBox.height)`
- `fx_bbox = (fx_user - boundingBox.x) / boundingBox.width`
- `fy_bbox = (fy_user - boundingBox.y) / boundingBox.height`

## Features

- **Automatic bounding box detection**: Reads from `viewBox` attribute or falls back to `width`/`height`
- **Multiple gradient support**: Handles multiple radial gradients in a single SVG
- **Focal point support**: Converts `fx` and `fy` coordinates for non-circular gradients
- **Gradient stops preservation**: Maintains all gradient stop colors and positions
- **Error handling**: Graceful handling of malformed SVG files
- **Detailed output**: Shows conversion details and file statistics

## Requirements

- macOS with Swift compiler
- Bash shell (for the shell script)

## Testing

The tool includes test files to verify functionality:

```bash
# Test objectBoundingBox to userSpaceOnUse conversion
./convert_gradients.sh test_boundingbox_gradient.svg converted_userspace.svg

# Test userSpaceOnUse to objectBoundingBox conversion
./convert_gradients.sh test_userspace_gradient.svg converted_boundingbox.svg --reverse

# Verify the conversions
diff test_userspace_gradient.svg converted_userspace.svg
```

## Integration with Xcode Project

The `GradientCoordinateConverter.swift` file is designed to be integrated into the existing Xcode project and can be used programmatically:

```swift
import Foundation

// Parse SVG content
let svgContent = try String(contentsOfFile: "input.svg")
let boundingBox = GradientCoordinateConverter.parseBoundingBox(from: svgContent)
let gradients = GradientCoordinateConverter.parseSVGGradients(from: svgContent)

// Convert gradients
let convertedGradients = gradients.map { gradient in
    GradientCoordinateConverter.convertBoundingBoxToUserSpace(
        gradient: gradient,
        boundingBox: boundingBox!
    )
}

// Generate new SVG
let outputContent = GradientCoordinateConverter.generateSVG(
    originalContent: svgContent,
    convertedGradients: convertedGradients,
    boundingBox: boundingBox!
)
```

## Limitations

- Only supports radial gradients (`<radialGradient>`)
- Requires valid SVG structure with proper gradient definitions
- Bounding box must be detectable from viewBox or width/height attributes
- Gradient stops must use percentage offsets

## Error Handling

The tool handles various error conditions:

- Missing or invalid viewBox/width/height attributes
- Malformed gradient definitions
- Missing gradient stops
- File I/O errors

All errors are reported with descriptive messages to help with debugging. 