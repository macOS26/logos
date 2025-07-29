//
//  RulersView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct RulersView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    
    private let rulerThickness: CGFloat = 20
    
    var body: some View {
        if document.showRulers {
            ZStack {
                // Horizontal Ruler (Top)
                HorizontalRuler(document: document, geometry: geometry)
                    .frame(height: rulerThickness)
                    .position(x: geometry.size.width / 2, y: rulerThickness / 2)
                
                // Vertical Ruler (Left)
                VerticalRuler(document: document, geometry: geometry)
                    .frame(width: rulerThickness)
                    .position(x: rulerThickness / 2, y: geometry.size.height / 2)
                
                // Corner Square
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: rulerThickness, height: rulerThickness)
                    .position(x: rulerThickness / 2, y: rulerThickness / 2)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                            .frame(width: rulerThickness, height: rulerThickness)
                            .position(x: rulerThickness / 2, y: rulerThickness / 2)
                    )
            }
        }
    }
}

struct HorizontalRuler: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    
    private let rulerThickness: CGFloat = 20
    
    var body: some View {
        GeometryReader { rulerGeometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
                        alignment: .bottom
                    )
                
                // Ruler marks and labels
                Canvas { context, size in
                    drawHorizontalRuler(context: context, size: size)
                }
            }
        }
    }
    
    private func drawHorizontalRuler(context: GraphicsContext, size: CGSize) {
        let unit = document.settings.unit
        let pointsPerUnit = unit.pointsPerUnit
        let zoomLevel = document.zoomLevel
        let canvasOffset = document.canvasOffset
        
        // CORRECTED RULER ALIGNMENT: Match exactly how canvas content is positioned
        // Canvas content position: x * zoomLevel + canvasOffset.x (in canvas coordinate space)
        // But canvas is offset by 20px due to ruler padding in MainView
        // So canvas coordinate 0 appears at: 0 * zoomLevel + canvasOffset.x + 20 in ruler space
        
        // Calculate what canvas coordinates are visible in the ruler
        let canvasPaddingOffset = 20.0  // Canvas is padded 20px from ruler edge
        let startX = (-canvasOffset.x - canvasPaddingOffset) / zoomLevel
        let endX = (size.width - canvasOffset.x - canvasPaddingOffset) / zoomLevel
        
        // Determine appropriate tick spacing
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)
        let majorTickInterval = getMajorTickInterval(for: unit)
        
        // Draw ticks and labels
        var x = floor(startX / tickSpacing) * tickSpacing
        while x <= endX {
            // CORRECTED: Canvas coordinate x appears at ruler position (x * zoom + offset + padding)
            let rulerX = x * zoomLevel + canvasOffset.x + canvasPaddingOffset
            
            if rulerX >= 0 && rulerX <= size.width {
                let isMajorTick = abs(x.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                
                // PROFESSIONAL INCH TICK HIERARCHY: Like Illustrator - 4 tiers
                let tickHeight: CGFloat
                let lineWidth: CGFloat
                
                if isMajorTick {
                    tickHeight = 12 // 1 inch ticks - full height
                    lineWidth = 1.0
                } else if abs(x.truncatingRemainder(dividingBy: majorTickInterval / 2)) < 0.001 {
                    tickHeight = 9  // 1/2 inch ticks - three-quarter height
                    lineWidth = 0.75
                } else if abs(x.truncatingRemainder(dividingBy: majorTickInterval / 4)) < 0.001 {
                    tickHeight = 6  // 1/4 inch ticks - half height
                    lineWidth = 0.6
                } else if abs(x.truncatingRemainder(dividingBy: majorTickInterval / 8)) < 0.001 {
                    tickHeight = 3  // 1/8 inch ticks - quarter height
                    lineWidth = 0.5
                } else {
                    // Skip ticks that aren't at proper intervals
                    x += tickSpacing
                    continue
                }
                
                // Draw tick with professional styling
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: rulerX, y: size.height - tickHeight))
                        path.addLine(to: CGPoint(x: rulerX, y: size.height))
                    },
                    with: .color(.primary),
                    lineWidth: lineWidth
                )
                
                // Draw label for major ticks only - AFTER the tick, not on top
                if isMajorTick {
                    let value = x / pointsPerUnit
                    let labelText = formatRulerValue(value, unit: unit)
                    
                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Position AFTER the tick, not on top - like Illustrator
                    context.draw(text, at: CGPoint(x: rulerX + 4, y: size.height - 14))
                }
            }
            
            x += tickSpacing
        }
    }
}

struct VerticalRuler: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    
    private let rulerThickness: CGFloat = 20
    
    var body: some View {
        GeometryReader { rulerGeometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
                        alignment: .trailing
                    )
                
                // Ruler marks and labels
                Canvas { context, size in
                    drawVerticalRuler(context: context, size: size)
                }
            }
        }
    }
    
    private func drawVerticalRuler(context: GraphicsContext, size: CGSize) {
        let unit = document.settings.unit
        let pointsPerUnit = unit.pointsPerUnit
        let zoomLevel = document.zoomLevel
        let canvasOffset = document.canvasOffset
        
        // PRECISE FIX: Vertical ruler alignment correction
        // User reported ticks are 12 pixels too low (south)
        // The vertical ruler needs to be shifted up by 12 pixels to align with canvas objects
        
        // Calculate what canvas coordinates are visible in the ruler
        let canvasPaddingOffset = 20.0  // Canvas is padded 20px from ruler edge
        let verticalAlignmentCorrection = 12.0  // Correction for vertical ruler positioning
        let startY = (-canvasOffset.y - canvasPaddingOffset) / zoomLevel
        let endY = (size.height - canvasOffset.y - canvasPaddingOffset) / zoomLevel
        
        // Determine appropriate tick spacing
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)
        let majorTickInterval = getMajorTickInterval(for: unit)
        
        // Draw ticks and labels
        var y = floor(startY / tickSpacing) * tickSpacing
        while y <= endY {
            // PRECISE FIX: Apply 12-pixel upward correction to align with canvas objects
            let rulerY = y * zoomLevel + canvasOffset.y + canvasPaddingOffset - verticalAlignmentCorrection
            
            if rulerY >= 0 && rulerY <= size.height {
                let isMajorTick = abs(y.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                
                // PROFESSIONAL INCH TICK HIERARCHY: Like Illustrator - 4 tiers
                let tickWidth: CGFloat
                let lineWidth: CGFloat
                
                if isMajorTick {
                    tickWidth = 12 // 1 inch ticks - full width
                    lineWidth = 1.0
                } else if abs(y.truncatingRemainder(dividingBy: majorTickInterval / 2)) < 0.001 {
                    tickWidth = 9  // 1/2 inch ticks - three-quarter width
                    lineWidth = 0.75
                } else if abs(y.truncatingRemainder(dividingBy: majorTickInterval / 4)) < 0.001 {
                    tickWidth = 6  // 1/4 inch ticks - half width
                    lineWidth = 0.6
                } else if abs(y.truncatingRemainder(dividingBy: majorTickInterval / 8)) < 0.001 {
                    tickWidth = 3  // 1/8 inch ticks - quarter width
                    lineWidth = 0.5
                } else {
                    // Skip ticks that aren't at proper intervals
                    y += tickSpacing
                    continue
                }
                
                // Draw tick with professional styling
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: size.width - tickWidth, y: rulerY))
                        path.addLine(to: CGPoint(x: size.width, y: rulerY))
                    },
                    with: .color(.primary),
                    lineWidth: lineWidth
                )
                
                // Draw label for major ticks only
                if isMajorTick {
                    let value = y / pointsPerUnit
                    let labelText = formatRulerValue(value, unit: unit)
                    
                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Rotate text for vertical ruler - AFTER the tick, not on top
                    var rotatedContext = context
                    rotatedContext.rotate(by: .degrees(-90))
                    rotatedContext.draw(text, at: CGPoint(x: -rulerY - 12, y: size.width - 14))
                }
            }
            
            y += tickSpacing
        }
    }
}

// Helper functions
private func getMajorTickInterval(for unit: MeasurementUnit) -> Double {
    let pointsPerUnit = unit.pointsPerUnit
    
    switch unit {
    case .pixels:
        return 50.0 // Major ticks every 50 pixels
    case .points:
        return 72.0 // Major ticks every 72 points (1 inch)
    case .inches:
        return pointsPerUnit // Major ticks every inch
    case .centimeters:
        return pointsPerUnit // Major ticks every centimeter
    case .millimeters:
        return pointsPerUnit * 10 // Major ticks every 10mm
    case .picas:
        return pointsPerUnit // Major ticks every pica (12 points)
    }
}

private func calculateTickSpacing(for unit: MeasurementUnit, zoomLevel: Double) -> Double {
    let pointsPerUnit = unit.pointsPerUnit
    
    // PROFESSIONAL TICK SPACING: Like Illustrator - clear, readable, properly scaled
    let baseSpacing: Double
    
    switch unit {
    case .pixels:
        // PROFESSIONAL: Use 50-pixel intervals for major ticks, 10-pixel for minor
        baseSpacing = 10.0 // 10-pixel minor ticks
    case .points:
        // Use 72-point intervals (1 inch) for major ticks, 12-point for minor
        baseSpacing = 12.0
    case .inches:
        // PROFESSIONAL INCHES: Use 1/8 inch intervals for ALL ticks (Illustrator standard)
        baseSpacing = pointsPerUnit / 8 // 1/8 inch intervals for finest subdivision
    case .centimeters:
        // PROFESSIONAL METRIC: Use 1cm intervals for major ticks, 1mm for minor
        baseSpacing = pointsPerUnit / 10 // 1mm intervals for minor ticks
    case .millimeters:
        // Use 10mm intervals for major ticks, 1mm for minor
        baseSpacing = pointsPerUnit
    case .picas:
        // PROFESSIONAL PICAS: Use 1 pica intervals for major ticks, 1 point for minor
        baseSpacing = pointsPerUnit / 12 // 1 point intervals for minor ticks
    }
    
    // Adjust spacing based on zoom level for professional readability
    let scaledSpacing = baseSpacing * zoomLevel
    
    // Choose appropriate spacing to avoid overcrowding while maintaining readability
    if scaledSpacing < 8 {
        return baseSpacing * 5 // Major ticks only when very zoomed out
    } else if scaledSpacing < 15 {
        return baseSpacing * 2 // Fewer minor ticks when zoomed out
    } else {
        return baseSpacing // Full detail when zoomed in
    }
}

private func formatRulerValue(_ value: Double, unit: MeasurementUnit) -> String {
    switch unit {
    case .inches:
        // PROFESSIONAL INCHES: Show whole numbers like Illustrator, no decimals
        return String(format: "%.0f", value)
    case .centimeters:
        // PROFESSIONAL CENTIMETERS: Show whole numbers like Illustrator, no decimals
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    case .millimeters:
        // FIXED: Handle negative values properly for mm
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    case .points:
        // LESS NOISY: Use cleaner formatting for points (no decimals but better spacing)
        return String(format: "%.0f", value)
    case .pixels:
        // LESS NOISY: Use cleaner formatting for pixels (no decimals but better spacing)
        return String(format: "%.0f", value)
    case .picas:
        // PROFESSIONAL PICAS: Show whole numbers like Illustrator, no decimals
        return String(format: "%.0f", value)
    }
}

// Guidelines for snapping
struct GuidelinesView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    @State private var horizontalGuidelines: [Double] = []
    @State private var verticalGuidelines: [Double] = []
    
    var body: some View {
        ZStack {
            // Horizontal guidelines
            ForEach(horizontalGuidelines, id: \.self) { y in
                Rectangle()
                    .fill(Color.cyan)
                    .frame(height: 1)
                    .position(x: geometry.size.width / 2, y: y * document.zoomLevel + document.canvasOffset.y)
                    .opacity(0.7)
            }
            
            // Vertical guidelines
            ForEach(verticalGuidelines, id: \.self) { x in
                Rectangle()
                    .fill(Color.cyan)
                    .frame(width: 1)
                    .position(x: x * document.zoomLevel + document.canvasOffset.x, y: geometry.size.height / 2)
                    .opacity(0.7)
            }
        }
    }
}

// Snap to grid functionality
extension VectorDocument {
    func snapToGrid(_ point: CGPoint) -> CGPoint {
        guard snapToGrid else { return point }
        
        let gridSpacing = settings.gridSpacing * settings.unit.pointsPerUnit
        
        // Prevent division by zero crash
        guard gridSpacing > 0 else { return point }
        
        let snappedX = round(point.x / gridSpacing) * gridSpacing
        let snappedY = round(point.y / gridSpacing) * gridSpacing
        
        return CGPoint(x: snappedX, y: snappedY)
    }
    
    func snapToGuidelines(_ point: CGPoint) -> CGPoint {
        // Implementation for snapping to guidelines
        return point
    }
}

// Units converter
struct UnitsConverter {
    static func convert(value: Double, from: MeasurementUnit, to: MeasurementUnit) -> Double {
        if from == to { return value }
        
        // Convert to points first
        let points = value * from.pointsPerUnit
        
        // Convert from points to target unit
        return points / to.pointsPerUnit
    }
    
    static func formatValue(_ value: Double, unit: MeasurementUnit) -> String {
        let convertedValue = value / unit.pointsPerUnit
        
        switch unit {
        case .inches:
            return String(format: "%.3f in", convertedValue)
        case .centimeters:
            return String(format: "%.2f cm", convertedValue)
        case .millimeters:
            return String(format: "%.1f mm", convertedValue)
        case .points:
            return String(format: "%.0f pt", convertedValue)
        case .pixels:
            return String(format: "%.0f px", convertedValue)
        case .picas:
            return String(format: "%.2f pc", convertedValue)
        }
    }
}

// Preview
struct RulersView_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { geometry in
            RulersView(document: VectorDocument(), geometry: geometry)
        }
        .frame(width: 600, height: 400)
    }
}