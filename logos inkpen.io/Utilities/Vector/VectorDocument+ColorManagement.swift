//
//  VectorDocument+ColorManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import Combine

// MARK: - Color Management
extension VectorDocument {
    
    // MARK: - Color Management - SIMPLIFIED
    func addColorToCurrentMode(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            if !customRgbSwatches.contains(color) {
                customRgbSwatches.append(color)
                objectWillChange.send() // Trigger UI update
            }
        case .cmyk:
            if !customCmykSwatches.contains(color) {
                customCmykSwatches.append(color)
                objectWillChange.send() // Trigger UI update
            }
        case .pms:
            if !customHsbSwatches.contains(color) {
                customHsbSwatches.append(color)
                objectWillChange.send() // Trigger UI update
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
            customRgbSwatches.removeAll { $0 == color }
        case .cmyk:
            customCmykSwatches.removeAll { $0 == color }
        case .pms:
            customHsbSwatches.removeAll { $0 == color }
        }
        objectWillChange.send() // Trigger UI update
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
        // FIX: Save undo state only once at the beginning, not for each object
        let shouldSaveUndo = !selectedObjectIDs.isEmpty
        if shouldSaveUndo {
            saveToUndoStack()
        }

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
                    if shape.isTextObject {
                        // MIGRATION: Use unified helpers instead of direct assignment
                        // FIX: Removed saveToUndoStack() - already saved once above
                        switch activeColorTarget {
                        case .fill:
                            updateTextFillColorInUnified(id: shape.id, color: color)
                        case .stroke:
                            updateTextStrokeColorInUnified(id: shape.id, color: color)
                        }
                        hasChanges = true
                    } else {
                        // Handle regular shapes in layers array
                        if let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil {
                            let shapes = getShapesForLayer(layerIndex)
                            if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }),
                               var updatedShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                                // FIX: Removed saveToUndoStack() - already saved once above
                                switch activeColorTarget {
                                case .fill:
                                    if updatedShape.fillStyle == nil {
                                        updatedShape.fillStyle = FillStyle(color: color)
                                    } else {
                                        updatedShape.fillStyle?.color = color
                                    }
                                case .stroke:
                                    if updatedShape.strokeStyle == nil {
                                        updatedShape.strokeStyle = StrokeStyle(color: color, placement: .center)
                                    } else {
                                        updatedShape.strokeStyle?.color = color
                                    }
                                }
                                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                                hasChanges = true
                            }
                        }
                    }
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

    // MARK: - Get Selected Object Color

    /// Get the fill or stroke color of the first selected object
    func getSelectedObjectColor() -> VectorColor? {
        guard let firstSelectedID = selectedObjectIDs.first else { return nil }

        if let unifiedObject = unifiedObjects.first(where: { $0.id == firstSelectedID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if activeColorTarget == .stroke {
                    return shape.strokeStyle?.color
                } else {
                    if shape.isTextObject {
                        // For text objects, use typography fillColor
                        return shape.typography?.fillColor
                    } else {
                        return shape.fillStyle?.color
                    }
                }
            }
        }

        return nil
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
        
        // Use explicit P3 RGB colors instead of system colors
        let p3Colors: [VectorColor] = [
            .rgb(RGBColor(red: 0.0, green: 0.478, blue: 1.0)),    // Blue (was systemBlue)
            .rgb(RGBColor(red: 1.0, green: 0.231, blue: 0.188)),  // Red (was systemRed)
            .rgb(RGBColor(red: 0.204, green: 0.780, blue: 0.349)), // Green (was systemGreen)
            .rgb(RGBColor(red: 1.0, green: 0.800, blue: 0.0)),    // Yellow (was systemYellow)
            .rgb(RGBColor(red: 1.0, green: 0.584, blue: 0.0)),    // Orange (was systemOrange)
            .rgb(RGBColor(red: 0.686, green: 0.322, blue: 0.871)), // Purple (was systemPurple)
            .rgb(RGBColor(red: 1.0, green: 0.176, blue: 0.333)),  // Pink (was systemPink)
            .rgb(RGBColor(red: 0.353, green: 0.784, blue: 0.980)), // Teal (was systemTeal)
            .rgb(RGBColor(red: 0.345, green: 0.337, blue: 0.839)), // Indigo (was systemIndigo)
            .rgb(RGBColor(red: 0.635, green: 0.518, blue: 0.368)), // Brown (was systemBrown)
            .rgb(RGBColor(red: 0.557, green: 0.557, blue: 0.576)), // Gray (was systemGray)
            .rgb(RGBColor(red: 0.682, green: 0.682, blue: 0.698)), // Gray2 (was systemGray2)
            .rgb(RGBColor(red: 0.780, green: 0.780, blue: 0.800))  // Gray3 (was systemGray3)
        ]
        
        return basicColors + rgbColors + p3Colors
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
