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
        // Canvas now fills the full view with no padding offset
        
        // Calculate what canvas coordinates are visible in the ruler
        let startX = (-canvasOffset.x) / zoomLevel
        let endX = (size.width - canvasOffset.x) / zoomLevel
        
        // Determine appropriate tick spacing
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)
        let majorTickInterval = getMajorTickInterval(for: unit)
        
        // Draw ticks and labels
        var x = floor(startX / tickSpacing) * tickSpacing
        while x <= endX {
            // CORRECTED: Canvas coordinate x appears at ruler position (x * zoom + offset)
            let rulerX = x * zoomLevel + canvasOffset.x
            
            if rulerX >= 0 && rulerX <= size.width {
                let isMajorTick = abs(x.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                
                // PROFESSIONAL TICK HIERARCHY: Longer ticks for all units (based on inches model)
                let tickHeight: CGFloat
                let lineWidth: CGFloat
                
                // Apply unified longer tick hierarchy to ALL units for consistent professional appearance
                if isMajorTick {
                    tickHeight = 16 // Major ticks - full height (LONGER - inches model)
                    lineWidth = 1.0
                } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 2)) < 0.001 {
                    tickHeight = 12  // Half-unit ticks - three-quarter height (LONGER - inches model)
                    lineWidth = 0.75
                } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 4)) < 0.001 {
                    tickHeight = 8  // Quarter-unit ticks - half height (LONGER - inches model)
                    lineWidth = 0.6
                } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 8)) < 0.001 {
                    tickHeight = 4  // Eighth-unit ticks - quarter height (LONGER - inches model)
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
                
                // Draw label for major ticks only - BEFORE the tick, not after
                if isMajorTick {
                    let value = x / pointsPerUnit
                    let labelText = formatRulerValue(value, unit: unit)
                    
                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Position RIGHT AFTER the tick mark
                    context.draw(text, at: CGPoint(x: rulerX + 8, y: size.height - 14))
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
        // Canvas now fills the full view with no padding offset
        
        // Calculate what canvas coordinates are visible in the ruler
        let verticalAlignmentCorrection = 12.0  // Correction for vertical ruler positioning
        let startY = (-canvasOffset.y) / zoomLevel
        let endY = (size.height - canvasOffset.y) / zoomLevel
        
        // Determine appropriate tick spacing
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)
        let majorTickInterval = getMajorTickInterval(for: unit)
        
        // Draw ticks and labels
        var y = floor(startY / tickSpacing) * tickSpacing
        while y <= endY {
            // PRECISE FIX: Apply 12-pixel upward correction to align with canvas objects
            let rulerY = y * zoomLevel + canvasOffset.y - verticalAlignmentCorrection
            
            if rulerY >= 0 && rulerY <= size.height {
                let isMajorTick = abs(y.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                
                // PROFESSIONAL TICK HIERARCHY: Longer ticks for all units (based on inches model)
                let tickWidth: CGFloat
                let lineWidth: CGFloat
                
                // Apply unified longer tick hierarchy to ALL units for consistent professional appearance
                if isMajorTick {
                    tickWidth = 16 // Major ticks - full width (LONGER - inches model)
                    lineWidth = 1.0
                } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 2)) < 0.001 {
                    tickWidth = 12  // Half-unit ticks - three-quarter width (LONGER - inches model)
                    lineWidth = 0.75
                } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 4)) < 0.001 {
                    tickWidth = 8  // Quarter-unit ticks - half width (LONGER - inches model)
                    lineWidth = 0.6
                } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 8)) < 0.001 {
                    tickWidth = 4  // Eighth-unit ticks - quarter width (LONGER - inches model)
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
                
                // Draw label for major ticks only - BEFORE the tick, not AFTER
                if isMajorTick {
                    let value = y / pointsPerUnit
                    let labelText = formatRulerValue(value, unit: unit)
                    
                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Rotate text for vertical ruler - RIGHT AFTER the tick, matching horizontal logic
                    var rotatedContext = context
                    rotatedContext.rotate(by: .degrees(-90))
                    rotatedContext.draw(text, at: CGPoint(x: -rulerY + 8, y: size.width - 14))
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
        return 60.0 // Major ticks every 60 pixels - clean, moderate spacing
    case .points:
        return 72.0 // Major ticks every 72 points (1 inch) - professional standard
    case .inches:
        return pointsPerUnit // Major ticks every inch - perfect
    case .centimeters:
        return pointsPerUnit // Major ticks every centimeter - appropriate
    case .millimeters:
        return pointsPerUnit * 10 // Major ticks every 10mm (1cm) - clean, readable
    case .picas:
        return pointsPerUnit // Major ticks every pica (12 points) - perfect model
    }
}

private func calculateTickSpacing(for unit: MeasurementUnit, zoomLevel: Double) -> Double {
    let pointsPerUnit = unit.pointsPerUnit
    
    // PROFESSIONAL TICK SPACING: Use PICAS frequency as model for ALL units
    // PICA model: 12 points per pica, with 1-point minor intervals = perfect frequency
    let baseSpacing: Double
    
    switch unit {
    case .pixels:
        // FIXED: Use PICA model - moderate density like 1 pica intervals
        baseSpacing = 12.0 // 12-pixel intervals - matches pica density perfectly
    case .points:
        // FIXED: Use PICA model - same 12-point intervals (1 pica worth)
        baseSpacing = 12.0 // 12-point intervals - exactly matches pica spacing
    case .inches:
        // Adaptive tick spacing for inches based on zoom level
        // Show all tick marks above 50%, then progressively drop ticks at lower zoom levels
        let scaledSpacing = (pointsPerUnit / 8) * zoomLevel // 1/8 inch intervals (9 points)
        
        if zoomLevel >= 0.5 {
            // Above 50% zoom: Show all tick marks (1/8 inch intervals)
            return pointsPerUnit / 8 // 9 points = 1/8 inch intervals
        } else if zoomLevel >= 0.33 {
            // At 33% zoom: Show 1/4 inch intervals
            return pointsPerUnit / 4 // 18 points = 1/4 inch intervals
        } else if zoomLevel >= 0.25 {
            // At 25% zoom: Show 1/2 inch intervals
            return pointsPerUnit / 2 // 36 points = 1/2 inch intervals
        } else {
            // Below 25% zoom: Show tick marks every 2 inches
            return pointsPerUnit * 2 // 144 points = 2 inch intervals
        }
    case .centimeters:
        // FIXED: Use larger intervals - match pica density (was 2mm, now ~3mm)
        baseSpacing = pointsPerUnit / 3 // ~3.33mm intervals (9.45 points) - matches pica density
    case .millimeters:
        // MUCH REDUCED: Use 10mm intervals instead of 5mm (matches pica major tick spacing)
        baseSpacing = pointsPerUnit * 10 // 10mm intervals (28.35 points) - clean, readable
    case .picas:
        // PERFECT MODEL: Keep existing pica spacing - this is the reference
        baseSpacing = pointsPerUnit / 12 // 1 point intervals - PERFECT frequency reference
    }
    
    // For non-inch units: Adjust spacing based on zoom level for professional readability
    if unit != .inches {
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
    
    // This should never be reached for inches due to early return above
    return baseSpacing
}

private func formatRulerValue(_ value: Double, unit: MeasurementUnit) -> String {
    switch unit {
    case .inches:
        // FIXED INCHES: Handle negative values properly like other units
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
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
        // FIXED: Handle negative values properly for points
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    case .pixels:
        // FIXED: Handle negative values properly for pixels
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    case .picas:
        // FIXED: Handle negative values properly for picas
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
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