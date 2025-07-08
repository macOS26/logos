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
                // Horizontal Ruler (Top) - FIXED ALIGNMENT: Account for canvas offset
                HorizontalRuler(document: document, geometry: geometry)
                    .frame(height: rulerThickness)
                    .offset(x: rulerThickness, y: 0)  // Offset to align with canvas
                    .position(x: geometry.size.width / 2, y: rulerThickness / 2)
                
                // Vertical Ruler (Left) - FIXED ALIGNMENT: Account for canvas offset  
                VerticalRuler(document: document, geometry: geometry)
                    .frame(width: rulerThickness)
                    .offset(x: 0, y: rulerThickness)  // Offset to align with canvas
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
        
        // FIXED RULER ALIGNMENT: Calculate ruler range starting from canvas origin (0,0)
        // The canvas coordinate 0 should appear at canvasOffset.x on screen
        let startX = (-canvasOffset.x) / zoomLevel  // Canvas coordinate at left edge of ruler
        let endX = (size.width - canvasOffset.x) / zoomLevel  // Canvas coordinate at right edge of ruler
        
        // Determine appropriate tick spacing
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)
        let majorTickInterval = tickSpacing * 5
        
        // Draw ticks and labels
        var x = floor(startX / tickSpacing) * tickSpacing
        while x <= endX {
            let screenX = x * zoomLevel + canvasOffset.x
            
            if screenX >= 0 && screenX <= size.width {
                let isMajorTick = abs(x.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                let tickHeight: CGFloat = isMajorTick ? 8 : 4
                
                // Draw tick
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: screenX, y: size.height - tickHeight))
                        path.addLine(to: CGPoint(x: screenX, y: size.height))
                    },
                    with: .color(.primary),
                    lineWidth: 0.5
                )
                
                // Draw label for major ticks
                if isMajorTick {
                    let value = x / pointsPerUnit
                    let labelText = formatRulerValue(value, unit: unit)
                    
                    let text = Text(labelText)
                        .font(.system(size: 8))
                        .foregroundColor(.primary)
                    
                    context.draw(text, at: CGPoint(x: screenX + 2, y: size.height - 12))
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
        
        // FIXED RULER ALIGNMENT: Calculate ruler range starting from canvas origin (0,0)
        // The canvas coordinate 0 should appear at canvasOffset.y on screen
        let startY = (-canvasOffset.y) / zoomLevel  // Canvas coordinate at top edge of ruler
        let endY = (size.height - canvasOffset.y) / zoomLevel  // Canvas coordinate at bottom edge of ruler
        
        // Determine appropriate tick spacing
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)
        let majorTickInterval = tickSpacing * 5
        
        // Draw ticks and labels
        var y = floor(startY / tickSpacing) * tickSpacing
        while y <= endY {
            let screenY = y * zoomLevel + canvasOffset.y
            
            if screenY >= 0 && screenY <= size.height {
                let isMajorTick = abs(y.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                let tickWidth: CGFloat = isMajorTick ? 8 : 4
                
                // Draw tick
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: size.width - tickWidth, y: screenY))
                        path.addLine(to: CGPoint(x: size.width, y: screenY))
                    },
                    with: .color(.primary),
                    lineWidth: 0.5
                )
                
                // Draw label for major ticks
                if isMajorTick {
                    let value = y / pointsPerUnit
                    let labelText = formatRulerValue(value, unit: unit)
                    
                    let text = Text(labelText)
                        .font(.system(size: 8))
                        .foregroundColor(.primary)
                    
                    // Rotate text for vertical ruler
                    var rotatedContext = context
                    rotatedContext.rotate(by: .degrees(-90))
                    rotatedContext.draw(text, at: CGPoint(x: -screenY - 8, y: size.width - 12))
                }
            }
            
            y += tickSpacing
        }
    }
}

// Helper functions
private func calculateTickSpacing(for unit: MeasurementUnit, zoomLevel: Double) -> Double {
    let pointsPerUnit = unit.pointsPerUnit
    let baseSpacing = pointsPerUnit / 8 // 1/8 unit by default
    
    // Adjust spacing based on zoom level
    let scaledSpacing = baseSpacing * zoomLevel
    
    // Choose appropriate spacing to avoid overcrowding
    if scaledSpacing < 10 {
        return baseSpacing * 4 // 1/2 unit
    } else if scaledSpacing < 20 {
        return baseSpacing * 2 // 1/4 unit
    } else {
        return baseSpacing // 1/8 unit
    }
}

private func formatRulerValue(_ value: Double, unit: MeasurementUnit) -> String {
    switch unit {
    case .inches:
        return String(format: "%.2f", value)
    case .centimeters:
        return String(format: "%.1f", value)
    case .millimeters:
        return String(format: "%.0f", value)
    case .points:
        return String(format: "%.0f", value)
    case .pixels:
        return String(format: "%.0f", value)
    case .picas:
        return String(format: "%.1f", value)
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