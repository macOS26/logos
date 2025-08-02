# Apple Pencil Pressure Sensitivity Implementation

## Overview

This implementation adds real Apple Pencil pressure sensitivity to InkPen on macOS, with intelligent fallback to speed-based simulation when pressure hardware is not available.

## Key Components

### 1. PressureSensitiveCanvasView.swift
- **NSView subclass** that handles real pressure events from Apple Pencil
- Uses `pressureChange(with:)`, `mouseDown(with:)`, `mouseDragged(with:)`, and `mouseUp(with:)` methods
- Automatically detects pressure capability using `NSEvent.pressureSupported`
- Converts NSView coordinates to canvas coordinates

### 2. PressureManager.swift
- **Centralized pressure management** with smart fallback
- Handles both real pressure input and speed-based simulation
- Published properties for SwiftUI integration
- Singleton pattern with `PressureManager.shared`

### 3. Integration Points
- **DrawingCanvas+BrushTool.swift**: Updated to use real pressure
- **DrawingCanvas+MarkerTool.swift**: Updated to use real pressure  
- **DrawingCanvas+ViewComposition.swift**: Added pressure-sensitive overlay
- **AppState.swift**: Now delegates to PressureManager

## How It Works

### Real Pressure Detection
1. `PressureSensitiveCanvasView` captures NSEvent pressure data
2. Events are routed through `handlePressureEvent()` 
3. `PressureManager` processes real pressure values (0.1 - 2.0 range)
4. Brush/Marker tools use the real pressure data

### Fallback Simulation
1. When no real pressure is detected, falls back to speed-based simulation
2. Fast drawing = lighter pressure, slow drawing = heavier pressure
3. Smoothed transitions for natural feel
4. User-configurable sensitivity settings

### Automatic Detection
- System automatically detects pressure capability on startup
- Switches to real pressure when Apple Pencil pressure events are received
- Updates `document.hasPressureInput` accordingly

## Usage

### For Drawing Tools
```swift
// Get pressure for current location (automatically chooses real vs simulated)
let pressure = PressureManager.shared.getPressure(for: location, sensitivity: sensitivity)

// Reset for new drawing
PressureManager.shared.resetForNewDrawing()

// Process real pressure events
PressureManager.shared.processRealPressure(pressure, at: location)
```

### For UI Components
```swift
// Check if pressure is available
if PressureManager.shared.hasRealPressureInput {
    // Show pressure-specific UI
}

// Monitor current pressure value
Text("Pressure: \(PressureManager.shared.currentPressure)")
```

## Testing

### Manual Testing
1. Run the app with Apple Pencil on supported Mac
2. Select Brush or Marker tool
3. Draw - pressure should vary stroke thickness
4. Check console for pressure detection logs

### Test View
Use `TestPressureDetection.swift` to verify pressure detection:
```swift
TestPressureDetection()
```

## Hardware Requirements

### ✅ Supported Configurations
- **Apple Pencil (2nd generation)** on supported Mac models
- **Apple Pencil Pro** on latest Mac models  
- **Direct connection** (not through AstroPad)

### ❌ Limited/No Support
- **Apple Pencil (USB-C)** - no pressure sensitivity
- **AstroPad mirroring** - pressure may be filtered out
- **External displays** - may not support pressure
- **Older Mac models** - check `NSEvent.pressureSupported`

## Console Logging

The implementation includes detailed logging for debugging:

```
🎨 PRESSURE: System reports pressure support available
🎨 PRESSURE: Mouse down - pressure: 1.0
🎨 PRESSURE: Real pressure event detected: 1.5
🎨 PRESSURE MANAGER: Updated pressure support: true
```

## Configuration

### Pressure Sensitivity Settings
- Located in Right Panel → Stroke/Fill Panel
- Separate settings for Brush and Marker tools
- Range: 0% - 100% sensitivity
- Real-time preview of pressure effect

### Developer Settings
```swift
// In PressureManager.swift
private let maxSpeed: Double = 100.0 // Simulation max speed
private let speedSmoothingFactor: Double = 0.3 // Smoothing amount
```

## Troubleshooting

### No Pressure Detected
1. **Check hardware compatibility**: Verify Mac model supports Apple Pencil pressure
2. **Test with native iPad app**: Confirm Apple Pencil works with pressure
3. **Check console logs**: Look for pressure detection messages
4. **Try different input**: Test with trackpad Force Touch if available

### AstroPad Issues  
1. **Use native macOS**: Direct Apple Pencil connection preferred
2. **Check AstroPad settings**: Update to latest version
3. **Adjust pressure curves**: AstroPad has extensive pressure customization

### Performance Issues
1. **Check smoothing settings**: Reduce pressure smoothing if laggy
2. **Monitor point array size**: Large drawings may need optimization
3. **Disable pressure temporarily**: Toggle in UI to test

## Future Enhancements

### Potential Improvements
- **Tilt detection** for brush orientation
- **Palm rejection** integration
- **Barrel rotation** for Apple Pencil Pro
- **Haptic feedback** integration
- **Custom pressure curves** per tool

### API Extensions
- Additional pressure event types (hover, lift)
- Per-tool pressure calibration
- Pressure recording/playback for testing
- Integration with PencilKit for mixed workflows

## Technical Notes

### Coordinate Systems
- NSView uses bottom-left origin
- Canvas uses top-left origin  
- Automatic conversion in `convertToCanvasCoordinates()`

### Event Handling
- Pressure overlay only active for brush/marker tools
- Non-interfering with other tool gestures
- Simultaneous gesture support maintained

### Memory Management
- Point arrays automatically trimmed to prevent memory issues
- Pressure manager is lightweight singleton
- No retain cycles in event handling