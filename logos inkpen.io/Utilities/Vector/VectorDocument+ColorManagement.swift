//
//  VectorDocument+ColorManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation

// MARK: - Color Management
extension VectorDocument {
    
    // MARK: - Color Management - SIMPLIFIED
    func addColorToCurrentMode(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            if !rgbSwatches.contains(color) {
                rgbSwatches.append(color)
            }
        case .cmyk:
            if !cmykSwatches.contains(color) {
                cmykSwatches.append(color)
            }
        case .pms:
            if !hsbSwatches.contains(color) {
                hsbSwatches.append(color)
            }
        }
    }
    
    func addColorSwatch(_ color: VectorColor) {
        addColorToCurrentMode(color)
    }
    
    func addColorToSwatches(_ color: VectorColor) {
        addColorToCurrentMode(color)
    }
    
    func removeColorFromCurrentMode(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            rgbSwatches.removeAll { $0 == color }
        case .cmyk:
            cmykSwatches.removeAll { $0 == color }
        case .pms:
            hsbSwatches.removeAll { $0 == color }
        }
    }
    
    // MARK: - Active Drawing Tool Notification
    
    /// Notify active drawing tools that fill opacity has changed
    func notifyActiveToolsOfFillOpacityChange() {
        lastColorChangeType = .fillOpacity
        colorChangeNotification = UUID()
        Log.fileOperation("🎨 VectorDocument: Notified active drawing tools of fill opacity change", level: .info)
    }
    
    /// Notify active drawing tools that stroke color has changed 
    func notifyActiveToolsOfStrokeColorChange() {
        lastColorChangeType = .strokeColor
        colorChangeNotification = UUID()
        Log.fileOperation("🎨 VectorDocument: Notified active drawing tools of stroke color change", level: .info)
    }
    
    /// Notify active drawing tools that stroke opacity has changed
    func notifyActiveToolsOfStrokeOpacityChange() {
        lastColorChangeType = .strokeOpacity
        colorChangeNotification = UUID()
        Log.fileOperation("🎨 VectorDocument: Notified active drawing tools of stroke opacity change", level: .info)
    }
    
    /// Generic notification for any color/opacity change (legacy support)
    func notifyActiveToolsOfColorChange() {
        lastColorChangeType = .fillOpacity // Default to fill opacity for legacy calls
        colorChangeNotification = UUID()
        Log.fileOperation("🎨 VectorDocument: Notified active drawing tools of color change", level: .info)
    }
    
    func setActiveColor(_ color: VectorColor) {
        switch activeColorTarget {
        case .fill:
            defaultFillColor = color
        case .stroke:
            defaultStrokeColor = color
        }
        
        // REFACTORED: Use unified objects system for color application
        var hasChanges = false
        
        // Apply to selected objects from unified system
        for objectID in selectedObjectIDs {
            if let unifiedObject = unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    // Find the shape in the layers array and update it
                    if let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil,
                       let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                        saveToUndoStack()
                        switch activeColorTarget {
                        case .fill:
                            if layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                                layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color)
                            } else {
                                layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                            }
                        case .stroke:
                            if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                                layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, placement: .center)
                            } else {
                                layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                            }
                        }
                        hasChanges = true
                    }
                    
                    // Text objects are now handled as VectorShape with isTextObject = true
                }
            }
        }
        
        // CRITICAL FIX: Sync unified objects for live color updates
        if hasChanges {
            updateUnifiedObjectsOptimized()
        }
    }
    
    func removeColorSwatch(_ color: VectorColor) {
        removeColorFromCurrentMode(color)
    }
    
    // SIMPLIFIED - No longer needed with separate arrays
    func updateColorSwatchesForMode() {
        // Nothing to do - each mode maintains its own array
        Log.fileOperation("🎨 Color mode switched to \(settings.colorMode.rawValue)", level: .info)
    }
    
    // SIMPLIFIED - Create default arrays for each mode
    static func createDefaultRGBSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        let rgbColors: [VectorColor] = [
            .rgb(RGBColor(red: 1, green: 0, blue: 0)),     // Red
            .rgb(RGBColor(red: 0, green: 1, blue: 0)),     // Green
            .rgb(RGBColor(red: 0, green: 0, blue: 1)),     // Blue
            .rgb(RGBColor(red: 1, green: 1, blue: 0)),     // Yellow
            .rgb(RGBColor(red: 1, green: 0, blue: 1)),     // Magenta
            .rgb(RGBColor(red: 0, green: 1, blue: 1)),     // Cyan
            .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5)), // Gray
            .rgb(RGBColor(red: 1, green: 0.5, blue: 0)),   // Orange
            .rgb(RGBColor(red: 0.5, green: 0, blue: 0.5)), // Purple
            .rgb(RGBColor(red: 0, green: 0.5, blue: 0)),   // Dark Green
            .rgb(RGBColor(red: 0, green: 0, blue: 0.5)),   // Dark Blue
            .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0)), // Olive
        ]
        
        let systemColors: [VectorColor] = [
            .appleSystem(.systemBlue),
            .appleSystem(.systemRed),
            .appleSystem(.systemGreen),
            .appleSystem(.systemYellow),
            .appleSystem(.systemOrange),
            .appleSystem(.systemPurple),
            .appleSystem(.systemPink),
            .appleSystem(.systemTeal),
            .appleSystem(.systemIndigo),
            .appleSystem(.systemBrown),
            .appleSystem(.systemGray),
            .appleSystem(.systemGray2),
            .appleSystem(.systemGray3),
            .appleSystem(.label),
            .appleSystem(.secondaryLabel),
            .appleSystem(.link)
        ]
        
        return basicColors + rgbColors + systemColors
    }
    
    static func createDefaultCMYKSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        var cmykColors: [VectorColor] = []
        
        // Professional CMYK color swatches for print production
        let cmykValues = [
            // Primary CMYK colors
            (100, 0, 0, 0),    // Cyan 100%
            (0, 100, 0, 0),    // Magenta 100%
            (0, 0, 100, 0),    // Yellow 100%
            (0, 0, 0, 100),    // Black 100%
            
            // Secondary colors (print mixing)
            (100, 100, 0, 0),  // Blue (C+M)
            (0, 100, 100, 0),  // Red (M+Y)
            (100, 0, 100, 0),  // Green (C+Y)
            
            // Professional print colors
            (100, 0, 0, 25),   // Dark Cyan
            (0, 100, 0, 25),   // Dark Magenta
            (0, 0, 100, 25),   // Dark Yellow
            
            // Grays (K-only for proper neutral grays)
            (0, 0, 0, 25),     // 25% Gray
            (0, 0, 0, 50),     // 50% Gray
            (0, 0, 0, 75),     // 75% Gray
            
            // Rich blacks for professional printing
            (30, 30, 30, 100), // Rich Black (recommended)
            (40, 40, 40, 100), // Super Rich Black
            
            // Professional skin tones (CMYK)
            (0, 30, 45, 0),    // Light Skin
            (0, 40, 60, 10),   // Medium Skin
            (0, 50, 75, 25),   // Dark Skin
        ]
        
        for (c, m, y, k) in cmykValues {
            let cmykColor = CMYKColor(
                cyan: Double(c) / 100.0,
                magenta: Double(m) / 100.0,
                yellow: Double(y) / 100.0,
                black: Double(k) / 100.0
            )
            cmykColors.append(.cmyk(cmykColor))
        }
        
        return basicColors + cmykColors
    }
    
    static func createDefaultHSBSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        
        // Create HSB spectrum colors
        var hsbColors: [VectorColor] = []
        
        // Primary hues (every 30 degrees) at full saturation and brightness
        for hue in stride(from: 0, to: 360, by: 30) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 1.0, brightness: 1.0)
            hsbColors.append(.hsb(hsbColor))
        }
        
        // Add some desaturated versions
        for hue in stride(from: 0, to: 360, by: 60) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 0.5, brightness: 0.8)
            hsbColors.append(.hsb(hsbColor))
        }
        
        // Add some darker versions
        for hue in stride(from: 0, to: 360, by: 90) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 0.8, brightness: 0.5)
            hsbColors.append(.hsb(hsbColor))
        }
        
        return basicColors + hsbColors
    }
}
