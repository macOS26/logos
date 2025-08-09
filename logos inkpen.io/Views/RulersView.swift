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
                    .fill(Color.ui.controlBackground)
                    .frame(width: rulerThickness, height: rulerThickness)
                    .position(x: rulerThickness / 2, y: rulerThickness / 2)
                    .overlay(
                        Rectangle()
                            .stroke(Color.ui.lightGrayBorder, lineWidth: 0.5)
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
                    .fill(Color.ui.controlBackground)
                    .overlay(
                        Rectangle()
                            .stroke(Color.ui.lightGrayBorder, lineWidth: 0.5),
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
        let majorTickInterval = getMajorTickInterval(for: unit, zoomLevel: zoomLevel)
        
        // Draw ticks and labels
        var x = floor(startX / tickSpacing) * tickSpacing
        while x <= endX {
            // CORRECTED: Canvas coordinate x appears at ruler position (x * zoom + offset)
            let rulerX = x * zoomLevel + canvasOffset.x
            
            if rulerX >= 0 && rulerX <= size.width {
                // Base major detection; may be overridden for certain units (e.g., centimeters)
                var isMajorTick = abs(x.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                var labelUsesMajor = isMajorTick
                
                // PROFESSIONAL TICK HIERARCHY
                let tickHeight: CGFloat
                let lineWidth: CGFloat
                if unit == .pixels || unit == .points {
                    // Pixel ruler: 50 px major ticks with 10 px minors
                    if isMajorTick {
                        tickHeight = 16
                        lineWidth = 1.0
                    } else {
                        tickHeight = 6
                        lineWidth = 0.5
                    }
                } else if unit == .picas {
                    // Picas ruler hierarchy with controlled density
                    // For 100%–399%: show only major, half-major, and quarter-major ticks
                    // For ≥400%: also show 3-pt and 1-pt hairlines
                    let majorStep = getMajorTickInterval(for: .picas, zoomLevel: zoomLevel)
                    let halfStep = majorStep / 2.0
                    let quarterStep = majorStep / 4.0
                    let eighthStep = majorStep / 8.0
                    let epsilon = 0.001

                    let isMajor = abs(x.truncatingRemainder(dividingBy: majorStep)) < epsilon
                    let isHalf = abs(x.truncatingRemainder(dividingBy: halfStep)) < epsilon
                    let isQuarter = abs(x.truncatingRemainder(dividingBy: quarterStep)) < epsilon
                    let isEighth = abs(x.truncatingRemainder(dividingBy: eighthStep)) < epsilon
                    let isThreePoint = abs(x.truncatingRemainder(dividingBy: 3.0)) < epsilon

                    if zoomLevel < 3.0 {
                        // 100%–399% pattern
                        if isMajor {
                            tickHeight = 16
                            lineWidth = 1.0
                        } else if isHalf {
                            tickHeight = 12 // 2nd highest
                            lineWidth = 0.75
                        } else if isQuarter {
                            tickHeight = 8 // mid tick (1 pica)
                            lineWidth = 0.6
                        } else if isEighth {
                            tickHeight = 4 // shortest (0.5 pica)
                            lineWidth = 0.5
                        } else if isThreePoint {
                            // Ensure smallest hairlines are at 3-point intervals (divisible by 3)
                            tickHeight = 3
                            lineWidth = 0.5
                        } else {
                            x += tickSpacing
                            continue
                        }
                    } else {
                        // ≥300%: allow denser 3pt/1pt structure on top of the above
                        if isMajor {
                            tickHeight = 16
                            lineWidth = 1.0
                        } else if abs(x.truncatingRemainder(dividingBy: 6.0)) < epsilon { // half pica
                            tickHeight = 12
                            lineWidth = 0.75
                        } else if abs(x.truncatingRemainder(dividingBy: 3.0)) < epsilon { // 3 pt
                            tickHeight = 8
                            lineWidth = 0.6
                        } else if abs(x.truncatingRemainder(dividingBy: 1.0)) < epsilon { // 1 pt
                            tickHeight = 4
                            lineWidth = 0.5
                        } else {
                            x += tickSpacing
                            continue
                        }
                    }
                } else if unit == .centimeters || unit == .millimeters {
                    // Professional metric style: 1 cm majors, 5 mm mids, 1 mm minors
                    // Use integer mm indexing to avoid floating point drift and skipped labels
                    let mmPoints = MeasurementUnit.millimeters.pointsPerUnit
                    let mmIndex = Int(round(x / mmPoints))

                    let isCentimeter = (mmIndex % 10 == 0)
                    let isHalfCentimeter = (mmIndex % 5 == 0)

                    // Override base major detection and labeling logic for centimeters and millimeters
                    if unit == .centimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    } else if unit == .millimeters {
                        // In mm mode, majors are every 10 mm (1 cm). Labels are 10,20,30…
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    }

                    if isCentimeter {
                        tickHeight = 16
                        lineWidth = 1.0
                    } else if isHalfCentimeter {
                        tickHeight = 10
                        lineWidth = 0.7
                    } else {
                        tickHeight = 6
                        lineWidth = 0.5
                    }
                } else {
                    // Other units keep the professional inches-style hierarchy
                    if isMajorTick {
                        tickHeight = 16
                        lineWidth = 1.0
                    } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 2)) < 0.001 {
                        tickHeight = 12
                        lineWidth = 0.75
                    } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 4)) < 0.001 {
                        tickHeight = 8
                        lineWidth = 0.6
                    } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 8)) < 0.001 {
                        tickHeight = 4
                        lineWidth = 0.5
                    } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 16)) < 0.001 {
                        // New 1/16-inch hairline ticks (shorter than 1/8)
                        tickHeight = 3
                        lineWidth = 0.5
                    } else {
                        // Skip ticks that aren't at proper intervals
                        x += tickSpacing
                        continue
                    }
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
                
                // Draw label for major ticks only
                if labelUsesMajor {
                    var labelText: String
                    if unit == .millimeters {
                        // Show 10, 20, 30 ... where each major is 10 mm
                        // Ensure we never render "-0" by converting to Int after rounding
                        let mmValue = (x / MeasurementUnit.millimeters.pointsPerUnit).rounded()
                        let mmInt = Int(mmValue)
                        labelText = String(mmInt)
                    } else {
                        let value = x / pointsPerUnit
                        labelText = formatRulerValue(value, unit: unit)
                    }

                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.ui.primaryText)

                    // Place label to the RIGHT of the major tick (uniform 3px offset for all units)
                    let offsetX: CGFloat = 3
                    context.draw(text, at: CGPoint(x: rulerX + offsetX, y: size.height - 14), anchor: .leading)
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
                // Background (snap 1px down to avoid sharing the same pixel row as canvas)
                Rectangle()
                    .fill(Color.ui.controlBackground)
                    .overlay(
                        Rectangle()
                            .stroke(Color.ui.lightGrayBorder, lineWidth: 0.5),
                        alignment: .trailing
                    )
                    .offset(y: 0.5) // pixel-snap to ensure the hairline is rendered fully above the canvas
                
                // Ruler marks and labels
                Canvas { context, size in
                    // Shift drawing context by 1px to align ticks with the snapped background
                    var ctx = context
                    ctx.translateBy(x: 0, y: 0.5)
                    drawVerticalRuler(context: ctx, size: size)
                }
            }
        }
    }
    
    private func drawVerticalRuler(context: GraphicsContext, size: CGSize) {
        let unit = document.settings.unit
        let pointsPerUnit = unit.pointsPerUnit
        let zoomLevel = document.zoomLevel
        let canvasOffset = document.canvasOffset
        
        // FIXED: Vertical ruler alignment - coordinate system now properly aligned
        // Canvas now fills the full view with no padding offset
        
        // Calculate what canvas coordinates are visible in the ruler
        let startY = (-canvasOffset.y) / zoomLevel
        let endY = (size.height - canvasOffset.y) / zoomLevel
        
        // Determine appropriate tick spacing
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)
        let majorTickInterval = getMajorTickInterval(for: unit, zoomLevel: zoomLevel)
        
        // Draw ticks and labels
        var y = floor(startY / tickSpacing) * tickSpacing
        while y <= endY {
            // FIXED: No correction needed - coordinate system now properly aligned
            let rulerY = y * zoomLevel + canvasOffset.y
            
            if rulerY >= 0 && rulerY <= size.height {
                // Base major detection; may be overridden for certain units (e.g., centimeters)
                var isMajorTick = abs(y.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                var labelUsesMajor = isMajorTick
                
                // PROFESSIONAL TICK HIERARCHY
                let tickWidth: CGFloat
                let lineWidth: CGFloat
                if unit == .pixels || unit == .points {
                    // Pixel ruler: 50 px major ticks with 10 px minors
                    if isMajorTick {
                        tickWidth = 16
                        lineWidth = 1.0
                    } else {
                        tickWidth = 6
                        lineWidth = 0.5
                    }
                } else if unit == .picas {
                    // Picas ruler hierarchy with controlled density (vertical)
                    let majorStep = getMajorTickInterval(for: .picas, zoomLevel: zoomLevel)
                    let halfStep = majorStep / 2.0
                    let quarterStep = majorStep / 4.0
                    let eighthStep = majorStep / 8.0
                    let epsilon = 0.001

                    let isMajor = abs(y.truncatingRemainder(dividingBy: majorStep)) < epsilon
                    let isHalf = abs(y.truncatingRemainder(dividingBy: halfStep)) < epsilon
                    let isQuarter = abs(y.truncatingRemainder(dividingBy: quarterStep)) < epsilon
                    let isEighth = abs(y.truncatingRemainder(dividingBy: eighthStep)) < epsilon
                    let isThreePoint = abs(y.truncatingRemainder(dividingBy: 3.0)) < epsilon

                    if zoomLevel < 3.0 {
                        // 100%–399% pattern
                        if isMajor {
                            tickWidth = 16
                            lineWidth = 1.0
                        } else if isHalf {
                            tickWidth = 12 // 2nd highest
                            lineWidth = 0.75
                        } else if isQuarter {
                            tickWidth = 8 // mid tick (1 pica)
                            lineWidth = 0.6
                        } else if isEighth {
                            tickWidth = 4 // shortest (0.5 pica)
                            lineWidth = 0.5
                        } else if isThreePoint {
                            tickWidth = 3 // ensure smallest ticks at 3pt multiples
                            lineWidth = 0.5
                        } else {
                            y += tickSpacing
                            continue
                        }
                    } else {
                        // ≥300%: denser 3pt/1pt structure
                        if isMajor {
                            tickWidth = 16
                            lineWidth = 1.0
                        } else if abs(y.truncatingRemainder(dividingBy: 6.0)) < epsilon {
                            tickWidth = 12
                            lineWidth = 0.75
                        } else if abs(y.truncatingRemainder(dividingBy: 3.0)) < epsilon {
                            tickWidth = 8
                            lineWidth = 0.6
                        } else if abs(y.truncatingRemainder(dividingBy: 1.0)) < epsilon {
                            tickWidth = 4
                            lineWidth = 0.5
                        } else {
                            y += tickSpacing
                            continue
                        }
                    }
                } else if unit == .centimeters || unit == .millimeters {
                    // Professional metric style: 1 cm majors, 5 mm mids, 1 mm minors
                    // Use integer mm indexing to avoid floating point drift and skipped labels
                    let mmPoints = MeasurementUnit.millimeters.pointsPerUnit
                    let mmIndex = Int(round(y / mmPoints))

                    let isCentimeter = (mmIndex % 10 == 0)
                    let isHalfCentimeter = (mmIndex % 5 == 0)

                    // Override base major detection and labeling logic for centimeters and millimeters
                    if unit == .centimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    } else if unit == .millimeters {
                        // In mm mode, majors are every 10 mm (1 cm). Labels are 10,20,30…
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    }

                    if isCentimeter {
                        tickWidth = 16
                        lineWidth = 1.0
                    } else if isHalfCentimeter {
                        tickWidth = 10
                        lineWidth = 0.7
                    } else {
                        tickWidth = 6
                        lineWidth = 0.5
                    }
                } else {
                    if isMajorTick {
                        tickWidth = 16
                        lineWidth = 1.0
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 2)) < 0.001 {
                        tickWidth = 12
                        lineWidth = 0.75
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 4)) < 0.001 {
                        tickWidth = 8
                        lineWidth = 0.6
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 8)) < 0.001 {
                        tickWidth = 4
                        lineWidth = 0.5
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 16)) < 0.001 {
                        // New 1/16-inch hairline ticks (shorter than 1/8)
                        tickWidth = 3
                        lineWidth = 0.5
                    } else {
                        // Skip ticks that aren't at proper intervals
                        y += tickSpacing
                        continue
                    }
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
                if labelUsesMajor {
                    var labelText: String
                    if unit == .millimeters {
                        let mmValue = (y / MeasurementUnit.millimeters.pointsPerUnit).rounded()
                        let mmInt = Int(mmValue)
                        labelText = String(mmInt)
                    } else {
                        let value = y / pointsPerUnit
                        labelText = formatRulerValue(value, unit: unit)
                    }

                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.ui.primaryText)

                    // Rotate text for vertical ruler and place depending on unit
                    var rotatedContext = context
                    rotatedContext.rotate(by: .degrees(-90))

                    // Place label to the RIGHT of the tick; uniform 3px offset for all units
                    let offsetX: CGFloat = 3
                    rotatedContext.draw(text, at: CGPoint(x: -rulerY + offsetX, y: size.width - 14), anchor: .leading)
                }
            }
            
            y += tickSpacing
        }
    }
}

// Helper functions
private func getMajorTickInterval(for unit: MeasurementUnit, zoomLevel: Double) -> Double {
    let pointsPerUnit = unit.pointsPerUnit
    
    switch unit {
    case .pixels, .points:
        // Adaptive major intervals for pixel rulers based on zoom
        if zoomLevel >= 1.0 {
            return 50.0
        } else if zoomLevel >= 0.5 {
            return 100.0
        } else if zoomLevel >= 0.25 {
            return 200.0
        } else {
            return 400.0
        }
    case .inches:
        return pointsPerUnit // Major ticks every inch - perfect
    case .centimeters:
        // Centimeters: majors at every 1 cm regardless of zoom
        return pointsPerUnit
    case .millimeters:
        // Millimeters: mirror centimeters exactly — majors every 10 mm (1 cm)
        return pointsPerUnit * 10
    case .picas:
        // Illustrator-style labeling for picas
        // 400% → 0,1,2,3 (every 1 pica)
        // 200% → 0,2,4 (every 2 picas)
        // 100% → 0,4,8 (every 4 picas)
        if zoomLevel >= 4.0 {
            return pointsPerUnit * 1
        } else if zoomLevel >= 2.0 {
            return pointsPerUnit * 2
        } else if zoomLevel >= 1.0 {
            return pointsPerUnit * 4
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit * 8
        } else {
            return pointsPerUnit * 16
        }
    }
}

private func calculateTickSpacing(for unit: MeasurementUnit, zoomLevel: Double) -> Double {
    let pointsPerUnit = unit.pointsPerUnit
    
    // PROFESSIONAL TICK SPACING: Use PICAS frequency as model for ALL units
    // PICA model: 12 points per pica, with 1-point minor intervals = perfect frequency
    let baseSpacing: Double
    
    switch unit {
    case .pixels, .points:
        // Pixels/Points: adaptive minor spacing to keep 5 subdivisions per major
        if zoomLevel >= 1.0 {
            return 10.0 // 50 major / 5
        } else if zoomLevel >= 0.5 {
            return 20.0 // 100 major / 5
        } else if zoomLevel >= 0.25 {
            return 40.0 // 200 major / 5
        } else {
            return 80.0 // 400 major / 5
        }
    case .inches:
        // Adaptive tick spacing for inches based on zoom level
        // 100%+: 1/16 inch intervals so 1/16 ticks can render
        if zoomLevel >= 1.0 {
            return pointsPerUnit / 16 // 4.5 points = 1/16 inch intervals
        } else if zoomLevel >= 0.5 {
            // 50%–99%: 1/8 inch intervals
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
        // CM: consistent 1 mm minor spacing where practical; scale out conservatively
        if zoomLevel >= 1.0 {
            return pointsPerUnit / 10 // 1 mm
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit / 5  // 2 mm
        } else if zoomLevel >= 0.25 {
            return pointsPerUnit / 2  // 5 mm
        } else {
            return pointsPerUnit      // 1 cm when zoomed far out
        }
    case .millimeters:
        // Millimeters: same layout as centimeters but in mm units
        // Full detail at ≥100%: 1 mm minors; scale out to 2/5/10 mm
        if zoomLevel >= 1.0 {
            return pointsPerUnit          // 1 mm
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit * 2      // 2 mm
        } else if zoomLevel >= 0.25 {
            return pointsPerUnit * 5      // 5 mm
        } else {
            return pointsPerUnit * 10     // 10 mm (1 cm)
        }
    case .picas:
        // Minor spacing adapts to keep readable subdivisions under the major scheme above
        if zoomLevel >= 4.0 {
            return 1.0        // 1 point ticks at 400%+
        } else if zoomLevel >= 2.0 {
            return 1.0        // 1 point ticks at 200%
        } else if zoomLevel >= 1.0 {
            return 1.0        // 1 point ticks at 100%
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit      // 1 pica at 50%
        } else {
            return pointsPerUnit * 2  // 2 picas when zoomed further out
        }
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
