//
//  VerticalToolbar.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

// Stroke settings for toolbar icons
private let IconStrokeWidth: CGFloat = 1.0
private let IconStrokeExpand: CGFloat = IconStrokeWidth / 2.0

// MARK: - Shape Variants

// Rectangle Variants
enum RectangleVariant: String, CaseIterable {
    case rectangle = "Rectangle"
    case square = "Square"
    case roundedRectangle = "Rounded Rectangle"
    case pill = "Pill"
    
    @ViewBuilder
    func iconView(isSelected: Bool, color: Color = .primary) -> some View {
        switch self {
        case .rectangle:
            RectangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .square:
            SquareIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .roundedRectangle:
            RoundedRectangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .pill:
            PillIcon(isSelected: isSelected)
                .foregroundColor(color)
        }
    }
}

// Circle Variants  
enum CircleVariant: String, CaseIterable {
    case ellipse = "Ellipse"
    case oval = "Oval"
    case circle = "Circle"
    case egg = "Egg"
    case cone = "Cone"
    
    @ViewBuilder
    func iconView(isSelected: Bool, color: Color = .primary) -> some View {
        switch self {
        case .ellipse:
            EllipseIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .oval:
            OvalIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .circle:
            CircleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .egg:
            EggIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .cone:
            ConeIcon(isSelected: isSelected)
                .foregroundColor(color)
        }
    }
}

// Triangle Variants
enum TriangleVariant: String, CaseIterable {
    case equilateral = "Equilateral Triangle"
    case right = "Right Triangle"
    case acute = "Acute Triangle"
    
    @ViewBuilder
    func iconView(isSelected: Bool, color: Color = .primary) -> some View {
        switch self {
        case .equilateral:
            EquilateralTriangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .right:
            RightTriangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .acute:
            AcuteTriangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        }
    }
}

// Polygon Variants
enum PolygonVariant: String, CaseIterable {
    case pentagon = "Pentagon (5 sides)"
    case hexagon = "Hexagon (6 sides)"
    case heptagon = "Heptagon (7 sides)"
    case octagon = "Octagon (8 sides)"
    case nonagon = "Nonagon (9 sides)"
}

// MARK: - Star Variants
enum StarVariant: String, CaseIterable {
    case threePoint = "3-Point Star"
    case fourPoint = "4-Point Star" 
    case fivePoint = "5-Point Star"
    case sixPoint = "6-Point Star"
    case sevenPoint = "7-Point Star"
    
    @ViewBuilder
    func iconView(isSelected: Bool, color: Color = .primary) -> some View {
        switch self {
        case .threePoint:
            ThreePointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .fourPoint:
            FourPointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .fivePoint:
            FivePointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .sixPoint:
            SixPointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .sevenPoint:
            SevenPointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        }
    }
}

// MARK: - Conditional View Modifier Extension
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
}



// MARK: - Custom Star Icons

// 3-Point Star (Mercedes-style curved)
struct ThreePointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.22 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 3

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 4-Point Star (diamond/cross shaped)
struct FourPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.28 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 4

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 5-Point Star (classic star)
struct FivePointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.40 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 5

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 6-Point Star (Star of David style)
struct SixPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.40 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 6

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 7-Point Star
struct SevenPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.40 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 7

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 8-Point Star (compass rose style)
struct EightPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.40
            let points: Int = 8

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// MARK: - Custom Rectangle Icons

struct RectangleIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            let rect = CGRect(x: 4 - IconStrokeExpand, y: 6 - IconStrokeExpand, width: 12 + IconStrokeWidth, height: 8 + IconStrokeWidth)
            path.addRect(rect)
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

struct SquareIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            let rect = CGRect(x: 5 - IconStrokeExpand, y: 5 - IconStrokeExpand, width: 10 + IconStrokeWidth, height: 10 + IconStrokeWidth)
            path.addRect(rect)
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

struct RoundedRectangleIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            let rect = CGRect(x: 4 - IconStrokeExpand, y: 6 - IconStrokeExpand, width: 12 + IconStrokeWidth, height: 8 + IconStrokeWidth)
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

struct PillIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            let rect = CGRect(x: 4 - IconStrokeExpand, y: 7 - IconStrokeExpand, width: 12 + IconStrokeWidth, height: 6 + IconStrokeWidth)
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 3, height: 3))
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// MARK: - Custom Circle Icons

struct EllipseIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            let rect = CGRect(x: 3 - IconStrokeExpand, y: 6 - IconStrokeExpand, width: 14 + IconStrokeWidth, height: 8 + IconStrokeWidth)
            path.addEllipse(in: rect)
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

struct OvalIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            let rect = CGRect(x: 4 - IconStrokeExpand, y: 5 - IconStrokeExpand, width: 12 + IconStrokeWidth, height: 10 + IconStrokeWidth)
            path.addEllipse(in: rect)
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

struct CircleIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            let rect = CGRect(x: 5 - IconStrokeExpand, y: 5 - IconStrokeExpand, width: 10 + IconStrokeWidth, height: 10 + IconStrokeWidth)
            path.addEllipse(in: rect)
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

struct EggIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Create a proper egg shape using simple 4-curve approach
            let center = CGPoint(x: 10, y: 10)
            let radiusX: CGFloat = 4 + IconStrokeExpand
            let radiusY: CGFloat = 6 + IconStrokeExpand
            
            // SIMPLE EGG FORMULA: Use standard ellipse with vertical offset
            // The narrow end should be rounded, not pointed
            let eggOffset = radiusY * 0.3  // Vertical offset to create egg asymmetry
            
            // Use standard ellipse control points (0.552) for smooth curves
            let controlPointOffsetX = radiusX * 0.552
            let controlPointOffsetY = radiusY * 0.552
            
            // Start at rightmost point
            path.move(to: CGPoint(x: center.x + radiusX, y: center.y))
            
            // Curve 1: Right → Top (wider end)
            path.addCurve(
                to: CGPoint(x: center.x, y: center.y - radiusY - eggOffset),
                control1: CGPoint(x: center.x + radiusX, y: center.y - controlPointOffsetY),
                control2: CGPoint(x: center.x + controlPointOffsetX, y: center.y - radiusY - eggOffset)
            )
            
            // Curve 2: Top → Left (wider end)
            path.addCurve(
                to: CGPoint(x: center.x - radiusX, y: center.y),
                control1: CGPoint(x: center.x - controlPointOffsetX, y: center.y - radiusY - eggOffset),
                control2: CGPoint(x: center.x - radiusX, y: center.y - controlPointOffsetY)
            )
            
            // Curve 3: Left → Bottom (narrower end)
            path.addCurve(
                to: CGPoint(x: center.x, y: center.y + radiusY - eggOffset),
                control1: CGPoint(x: center.x - radiusX, y: center.y + controlPointOffsetY),
                control2: CGPoint(x: center.x - controlPointOffsetX, y: center.y + radiusY - eggOffset)
            )
            
            // Curve 4: Bottom → Right (narrower end)
            path.addCurve(
                to: CGPoint(x: center.x + radiusX, y: center.y),
                control1: CGPoint(x: center.x + controlPointOffsetX, y: center.y + radiusY - eggOffset),
                control2: CGPoint(x: center.x + radiusX, y: center.y + controlPointOffsetY)
            )
            
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

struct ConeIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Cone path using same proportions as canvas cone (DrawingCanvas+ShapeDrawing.swift)
            // Define an icon-space bounding rect similar to other icons
            let r = CGRect(
                x: 5 - IconStrokeExpand,
                y: 4 - IconStrokeExpand,
                width: 10 + IconStrokeWidth,
                height: 10 + IconStrokeWidth
            )

            let apex = CGPoint(x: r.midX, y: r.minY)
            let baseLeft = CGPoint(x: r.minX, y: r.maxY)
            let baseRight = CGPoint(x: r.maxX, y: r.maxY)

            let move = CGPoint(x: baseRight.x - r.width * 0.007461, y: baseRight.y - r.height * 0.13586)
            let c1 = CGPoint(x: baseRight.x - r.width * 0.002364, y: baseRight.y - r.height * 0.12957)
            let c2 = CGPoint(x: baseRight.x, y: baseRight.y - r.height * 0.12317)
            let rightStart = CGPoint(x: baseRight.x, y: baseRight.y - r.height * 0.11645)

            let c3 = CGPoint(x: baseRight.x, y: baseRight.y - r.height * 0.05216)
            let c4 = CGPoint(x: r.midX + r.width * 0.27608, y: r.maxY)
            let mid = CGPoint(x: r.midX, y: r.maxY)

            let c5 = CGPoint(x: r.midX - r.width * 0.27608, y: r.maxY)
            let c6 = CGPoint(x: baseLeft.x, y: baseLeft.y - r.height * 0.05216)
            let leftEnd = CGPoint(x: baseLeft.x, y: baseLeft.y - r.height * 0.11645)

            let c7 = CGPoint(x: baseLeft.x, y: baseLeft.y - r.height * 0.12160)
            let c8 = CGPoint(x: baseLeft.x + r.width * 0.00141, y: baseLeft.y - r.height * 0.12660)
            let leftExit = CGPoint(x: baseLeft.x + r.width * 0.00463, y: baseLeft.y - r.height * 0.13147)

            path.move(to: move)
            path.addCurve(to: rightStart, control1: c1, control2: c2)
            path.addCurve(to: mid, control1: c3, control2: c4)
            path.addCurve(to: leftEnd, control1: c5, control2: c6)
            path.addCurve(to: leftExit, control1: c7, control2: c8)
            path.addLine(to: apex)
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// MARK: - Custom Triangle Icons

struct EquilateralTriangleIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Perfect equilateral triangle
            let center = CGPoint(x: 10, y: 10)
            let height: CGFloat = 8
            let width: CGFloat = height * 2 / sqrt(3)
            
            let topPoint = CGPoint(x: center.x, y: center.y - height * 0.6 - IconStrokeExpand)
            let bottomLeft = CGPoint(x: center.x - width * 0.5 - IconStrokeExpand, y: center.y + height * 0.4 + IconStrokeExpand)
            let bottomRight = CGPoint(x: center.x + width * 0.5 + IconStrokeExpand, y: center.y + height * 0.4 + IconStrokeExpand)
            
            path.move(to: topPoint)
            path.addLine(to: bottomLeft)
            path.addLine(to: bottomRight)
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

struct RightTriangleIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Right triangle with 90-degree angle at bottom left
            let topLeft = CGPoint(x: 5 - IconStrokeExpand, y: 5 - IconStrokeExpand)
            let bottomLeft = CGPoint(x: 5 - IconStrokeExpand, y: 15 + IconStrokeExpand)
            let bottomRight = CGPoint(x: 15 + IconStrokeExpand, y: 15 + IconStrokeExpand)
            
            path.move(to: topLeft)
            path.addLine(to: bottomLeft)
            path.addLine(to: bottomRight)
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

struct AcuteTriangleIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Acute triangle (all angles less than 90 degrees)
            // Tall, narrow triangle with sharp angles
            let baseWidth: CGFloat = 8
            let height: CGFloat = 12
            
            let center = CGPoint(x: 10, y: 10)
            let topPoint = CGPoint(x: center.x, y: center.y - height * 0.5 - IconStrokeExpand)
            let bottomLeft = CGPoint(x: center.x - baseWidth * 0.5 - IconStrokeExpand, y: center.y + height * 0.5 + IconStrokeExpand)
            let bottomRight = CGPoint(x: center.x + baseWidth * 0.5 + IconStrokeExpand, y: center.y + height * 0.5 + IconStrokeExpand)
            
            path.move(to: topPoint)
            path.addLine(to: bottomLeft)
            path.addLine(to: bottomRight)
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// IsoscelesTriangleIcon removed – Equilateral is the primary triangle icon

// MARK: - Custom Skewed Rectangle Icon
struct SkewedRectangleIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Image(systemName: "rectangle")
            .font(.system(size: 16))
            .foregroundColor(isSelected ? .white : .primary)
            .transformEffect(CGAffineTransform(a: 1.0, b: 0.0, c: -0.3, d: 1.0, tx: 2, ty: 0))
    }
}

// MARK: - Custom Polygon Icons (5–9 sides) using the same math as canvas

private func polygonIconPath(center: CGPoint, radius: CGFloat, sides: Int) -> Path {
    var p = Path()
    let adjustedRadius = radius + IconStrokeExpand
    let angleStep = (2.0 * .pi) / Double(sides)
    let startAngle = -Double.pi / 2 + ((sides % 2 == 0) ? angleStep / 2 : 0)
    for i in 0..<sides {
        let angle = Double(i) * angleStep + startAngle
        let x = center.x + adjustedRadius * cos(CGFloat(angle))
        let y = center.y + adjustedRadius * sin(CGFloat(angle))
        if i == 0 {
            p.move(to: CGPoint(x: x, y: y))
        } else {
            p.addLine(to: CGPoint(x: x, y: y))
        }
    }
    p.closeSubpath()
    return p
}

struct PentagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 5)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

struct HexagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 6)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

struct HeptagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 7)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

struct OctagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 8)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

struct NonagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 9)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

// MARK: - Tool Item for flexible toolbar display
struct ToolItem {
    let tool: DrawingTool
    let starVariant: StarVariant?
    
    var toolIdentifier: String {
        if let variant = starVariant {
            return "star_\(variant.rawValue)"
        } else {
            return tool.rawValue
        }
    }
}

struct VerticalToolbar: View {
    @ObservedObject var document: VectorDocument
    @StateObject private var starHUDManager = StarToolHUDManager()
    @StateObject private var toolGroupManager = ToolGroupManager.shared

    // MARK: - Tool Group Functions
    
    private func handleToolLongPress(_ tool: DrawingTool, variantIndex: Int? = nil) {
        toolGroupManager.longPressedTool(tool, variantIndex: variantIndex)
        Log.fileOperation("🔧 Long press on tool: \(tool.rawValue)", level: .info)
    }
    
    // MARK: - Icon Display Functions
    
    @ViewBuilder
    private func toolIconView(for toolItem: ToolItem) -> some View {
        if toolItem.tool == .shear {
            // Use custom skewed rectangle icon for shear tool
            SkewedRectangleIcon(isSelected: document.currentTool == toolItem.tool)
        } else if toolItem.tool == .star, let starVariant = toolItem.starVariant {
            // Use specific star variant custom icon
            starVariant.iconView(
                isSelected: document.currentTool == .star && starHUDManager.selectedVariant == starVariant,
                color: (document.currentTool == .star && starHUDManager.selectedVariant == starVariant) ? .white : .primary
            )
        } else if toolItem.tool == .star {
            // Use selected star variant custom icon
            starHUDManager.selectedVariant.iconView(
                isSelected: document.currentTool == toolItem.tool,
                color: document.currentTool == toolItem.tool ? .white : .primary
            )
        } else {
            customShapeIconView(for: toolItem)
        }
    }
    
    @ViewBuilder
    private func customShapeIconView(for toolItem: ToolItem) -> some View {
        switch toolItem.tool {
        case .rectangle:
            RectangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .square:
            SquareIcon(isSelected: document.currentTool == toolItem.tool)
        case .roundedRectangle:
            RoundedRectangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .pill:
            PillIcon(isSelected: document.currentTool == toolItem.tool)
        case .ellipse:
            EllipseIcon(isSelected: document.currentTool == toolItem.tool)
        case .oval:
            OvalIcon(isSelected: document.currentTool == toolItem.tool)
        case .circle:
            CircleIcon(isSelected: document.currentTool == toolItem.tool)
        case .egg:
            EggIcon(isSelected: document.currentTool == toolItem.tool)
        case .cone:
            ConeIcon(isSelected: document.currentTool == toolItem.tool)
        case .equilateralTriangle:
            EquilateralTriangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .rightTriangle:
            RightTriangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .acuteTriangle:
            AcuteTriangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .pentagon:
            PentagonIcon(isSelected: document.currentTool == toolItem.tool)
        case .hexagon:
            HexagonIcon(isSelected: document.currentTool == toolItem.tool)
        case .heptagon:
            HeptagonIcon(isSelected: document.currentTool == toolItem.tool)
        case .octagon:
            OctagonIcon(isSelected: document.currentTool == toolItem.tool)
        case .nonagon:
            NonagonIcon(isSelected: document.currentTool == toolItem.tool)
        default:
            // Use SF Symbols for all other tools
            Image(systemName: toolItem.tool.iconName)
                .font(.system(size: 16))
                .foregroundColor(isToolSelected(toolItem) ? .white : .primary)
        }
    }
    
    // MARK: - Flexible Toolbar Display Logic
    
    private func getToolsToDisplay() -> [ToolItem] {
        var toolsToShow: [ToolItem] = []
        
        // Get all unique tool groups
        let allToolGroups = getAllToolGroups()
        
        for toolGroup in allToolGroups {
            let primaryTool = toolGroup[0]
            let groupName = ToolGroupConfiguration.getToolGroupName(for: primaryTool) ?? "single:\(primaryTool.rawValue)"
            
            // Expanded state is now per-group
            if toolGroupManager.expandedGroups.contains(groupName) {
                if primaryTool == .star {
                    // If we have a per-group anchor variant, put it first; otherwise natural order
                    if let anchorVariant = (toolGroupManager.anchorVariantByGroup[groupName] ?? nil) {
                        toolsToShow.append(ToolItem(tool: .star, starVariant: anchorVariant))
                        let otherVariants = StarVariant.allCases.filter { $0 != anchorVariant }
                        for variant in otherVariants {
                            toolsToShow.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    } else {
                        for variant in StarVariant.allCases {
                            toolsToShow.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    }
                } else {
                    for tool in toolGroup {
                        toolsToShow.append(ToolItem(tool: tool, starVariant: nil))
                    }
                }
            } else {
                // Collapsed state shows the group's selected tool (falls back to primary)
                if primaryTool == .star {
                    toolsToShow.append(ToolItem(tool: .star, starVariant: starHUDManager.selectedVariant))
                } else {
                    let selectedTool = toolGroupManager.selectedToolByGroup[groupName] ?? primaryTool
                    toolsToShow.append(ToolItem(tool: selectedTool, starVariant: nil))
                }
            }
        }
        
        return toolsToShow
    }
    
    private func getAllToolGroups() -> [[DrawingTool]] {
        // Ensure polygon group appears as 5,6,7,8,9 specifically
        var groups = ToolGroupConfiguration.getAllToolGroupsAsArrays()
        if let idx = groups.firstIndex(where: { $0.contains(.pentagon) && $0.contains(.octagon) }) {
            groups[idx] = [.pentagon, .hexagon, .heptagon, .octagon, .nonagon]
        }
        return groups
    }
    
    private func isToolSelected(_ toolItem: ToolItem) -> Bool {
        if let starVariant = toolItem.starVariant {
            return document.currentTool == .star && starHUDManager.selectedVariant == starVariant
        } else {
            return document.currentTool == toolItem.tool
        }
    }

    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    // Drawing Tools
                    ToolSection(title: "Drawing") {
                        ForEach(getToolsToDisplay(), id: \.toolIdentifier) { toolItem in
                            Button {
                                // Handle tool selection
                                if let starVariant = toolItem.starVariant {
                                    toolGroupManager.selectStarVariant(starVariant)
                                    starHUDManager.selectedVariant = starVariant
                                    document.currentTool = .star
                                    // Update tool group manager state
                                    toolGroupManager.currentToolInGroup = .star
                                    toolGroupManager.setSelectedToolInGroup(.star)
                                    Log.info("⭐ Selected star variant: \(starVariant.rawValue)", category: .general)
                                } else {
                                    document.currentTool = toolItem.tool
                                    // Update tool group manager state
                                    toolGroupManager.currentToolInGroup = toolItem.tool
                                    toolGroupManager.setSelectedToolInGroup(toolItem.tool)
                                    Log.info("🛠️ Switched to tool: \(toolItem.tool.rawValue)", category: .general)
                                }
                                
                                // Do not force cursor here; let canvas hover control cursor visibility.
                                // This avoids requiring long-press to see the cursor. The canvas will set
                                // the correct cursor on hover/enter.
                            } label: {
                                toolIconView(for: toolItem)
                                .frame(width: 32, height: 32)
                                .background(
                                    isToolSelected(toolItem)
                                    ? Color.blue.opacity(0.8)
                                    : Color.clear
                                )
                                .cornerRadius(4)
                                .contentShape(Rectangle()) // Extend hit area to match entire button area
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(toolTooltip(for: toolItem.tool, variant: toolItem.starVariant))
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            // Store the button's frame for tool group positioning
                                            let globalFrame = geometry.frame(in: .global)
                                            toolGroupManager.setToolButtonFrame(toolItem.tool, frame: globalFrame)
                                        }
                                        .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                                            // Update frame if it changes (e.g., during scrolling)
                                            toolGroupManager.setToolButtonFrame(toolItem.tool, frame: newFrame)
                                        }
                                }
                            )
                            .highPriorityGesture(
                                TapGesture()
                                    .onEnded { _ in
                                        // Handle tool selection
                                        if let starVariant = toolItem.starVariant {
                                            toolGroupManager.selectStarVariant(starVariant)
                                            starHUDManager.selectedVariant = starVariant
                                            document.currentTool = .star
                                            // Update tool group manager state
                                            toolGroupManager.currentToolInGroup = .star
                                            toolGroupManager.setSelectedToolInGroup(.star)
                                            Log.fileOperation("🔧 Tool tap detected: \(starVariant.rawValue)", level: .info)
                                        } else {
                                            document.currentTool = toolItem.tool
                                            // Update tool group manager state
                                            toolGroupManager.currentToolInGroup = toolItem.tool
                                            toolGroupManager.setSelectedToolInGroup(toolItem.tool)
                                            Log.fileOperation("🔧 Tool tap detected: \(toolItem.tool.rawValue)", level: .info)
                                        }
                                        
                                        // Do not force cursor here; canvas hover logic will set it.
                                    }
                            )
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        // Long press completed - expand tool group
                                        if let starVariant = toolItem.starVariant {
                                            let variantIndex = StarVariant.allCases.firstIndex(of: starVariant) ?? 0
                                            handleToolLongPress(.star, variantIndex: variantIndex)
                                        } else {
                                            handleToolLongPress(toolItem.tool)
                                        }
                                    }
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Quick Color Swatches
                    ToolSection(title: "Colors") {
                        ColorSwatchGrid(document: document)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .frame(width: 48) // ENSURE: Maintain fixed toolbar width
            }
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
                alignment: .trailing
            )
        }
    }
    

    
    private func toolTooltip(for tool: DrawingTool, variant: StarVariant? = nil) -> String {
        if let starVariant = variant {
            return "Star Tool - Draw \(starVariant.rawValue) (Long press for more variants)"
        }
        
        switch tool {
        case .selection:
            return "Selection Tool (V) - Select and move objects"
        case .scale:
            return "Scale Tool (S) - Scale objects with corner handles"
        case .rotate:
            return "Rotate Tool (R) - Rotate objects around anchor points"
        case .shear:
            return "Shear Tool (X) - Shear/skew objects around anchor points"
        case .directSelection:
            return "Direct Selection Tool (A) - Edit individual points and handles"
        case .convertAnchorPoint:
            return "Convert Anchor Point Tool (C) - Convert between smooth and corner points"
        case .bezierPen:
            return "Bezier Pen Tool (P) - Draw bezier curves and paths"
        case .freehand:
            return "Freehand Tool (F) - Draw freehand with smooth curves"
        case .brush:
            return "Brush Tool (B) - Draw variable width brush strokes"
        case .marker:
            return "Marker Tool (M) - Draw with circular felt-tip marker strokes"
        case .font:
            return "Font Tool (T) - Add and edit text"
        case .line:
            return "Line Tool (L) - Draw straight lines"
        case .rectangle:
            return "Rectangle Tool (⌥R) - Draw rectangles"
        case .square:
            return "Square Tool (⌥S) - Draw perfect squares"
        case .roundedRectangle:
            return "Rounded Rectangle Tool (⇧⌥R) - Draw rectangles with rounded corners"
        case .pill:
            return "Pill Tool (⇧⌥P) - Draw capsule/pill shapes"
        case .circle:
            return "Circle Tool (⌥C) - Draw perfect circles"
        case .ellipse:
            return "Ellipse Tool (E) - Draw ellipses and ovals"
        case .oval:
            return "Oval Tool (O) - Draw oval shapes"
        case .egg:
            return "Egg Tool (⇧E) - Draw egg shapes"
        case .cone:
            return "Cone Tool (⇧⌥C) - Draw triangle/cone shapes"
        case .equilateralTriangle:
            return "Equilateral Triangle Tool (⇧T) - Draw triangles with equal sides"
        case .isoscelesTriangle:
            return "Isosceles Triangle Tool (I) - Draw triangles with two equal sides"
        case .rightTriangle:
            return "Right Triangle Tool (⇧⌥R) - Draw 90-degree triangles"
        case .acuteTriangle:
            return "Acute Triangle Tool (⇧A) - Draw triangles with all angles less than 90°"
        case .star:
            return "Star Tool (⇧S) - Draw \(starHUDManager.selectedVariant.rawValue) (Long press for more variants)"
        case .polygon:
            return "Polygon Tool (⌥P) - Draw polygon shapes"
        case .pentagon:
            return "Pentagon Tool (5) - Draw 5-sided polygons"
        case .hexagon:
            return "Hexagon Tool (6) - Draw 6-sided polygons"
        case .heptagon:
            return "Heptagon Tool (7) - Draw 7-sided polygons"
        case .octagon:
            return "Octagon Tool (8) - Draw 8-sided polygons"
        case .nonagon:
            return "Nonagon Tool (9) - Draw 9-sided polygons"
        case .eyedropper:
            return "Eyedropper Tool (I) - Sample colors"
        case .hand:
            return "Hand Tool (H) - Pan the canvas"
        case .zoom:
            return "Zoom Tool (Z) - Zoom in and out"
        case .warp:
            return "Warp Tool (W) - Warp and distort objects"
        case .gradient:
            return "Gradient Tool (G) - Edit gradient origin and focal points"
        case .cornerRadius:
            return "Corner Radius Tool (⌥R) - Edit corner radius of rectangles"
        }
    }
}

struct ToolSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 4) {
            content
        }
    }
}

struct ToolButton: View {
    let tool: DrawingTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Group {
                if tool == .shear {
                    // Use custom skewed rectangle icon for shear tool
                    SkewedRectangleIcon(isSelected: isSelected)
                } else {
                    // Use SF Symbols for all other tools
                    Image(systemName: tool.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : .primary)
                }
            }
            .frame(width: 32, height: 32)
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .help(tool.rawValue)
    }
}



struct ColorSwatchGrid: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    @State private var selectedFillColor: VectorColor = .white
    @State private var selectedStrokeColor: VectorColor = .black
    @State private var showingColorPicker = false
    
    let columns = [
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1)
    ]
    
    // FIXED: Show current colors from text OR shapes
    private var currentFillColor: VectorColor {
        // PRIORITY 1: If text objects are selected, show their fill color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.fillColor
        }
        
        // PRIORITY 2: If shapes are selected, show their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let fillStyle = shape.fillStyle {
            // FIXED: Show the actual gradient, not default color
            return fillStyle.color
        }
        
        // PRIORITY 3: Show default color for new shapes
        return document.defaultFillColor
    }
    
    // FIXED: Show current colors from text OR shapes  
    private var currentStrokeColor: VectorColor {
        // PRIORITY 1: If text objects are selected, show their stroke color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeColor
        }
        
        // PRIORITY 2: If shapes are selected, show their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let strokeColor = shape.strokeStyle?.color {
            return strokeColor
        }
        
        // PRIORITY 3: Show default color for new shapes
        return document.defaultStrokeColor
    }
    
    // Get current fill opacity (from text OR shapes)
    private var currentFillOpacity: Double {
        // PRIORITY 1: If text objects are selected, show their fill opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.fillOpacity
        }
        
        // PRIORITY 2: If shapes are selected, show their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.fillStyle?.opacity {
            return opacity
        }
        
        // PRIORITY 3: Show default opacity
        return document.defaultFillOpacity
    }
    
    // Get current stroke opacity (from text OR shapes)
    private var currentStrokeOpacity: Double {
        // PRIORITY 1: If text objects are selected, show their stroke opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeOpacity
        }
        
        // PRIORITY 2: If shapes are selected, show their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.strokeStyle?.opacity {
            return opacity
        }
        return document.defaultStrokeOpacity
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Current Fill and Stroke Colors - Professional Style (overlapping squares)
            ZStack {
                // Stroke color (background, bottom-right)
                Button {
                    document.activeColorTarget = .stroke
                } label: {
                    if case .clear = currentStrokeColor {
                        ZStack {
                            // Checkerboard pattern for clear color
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
	                            
	                            Rectangle()
	                                .fill(Color.clear)
	                                .frame(width: 22, height: 22)
                            
                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }

                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else if case .gradient(let gradient) = currentStrokeColor {
                        // Handle gradient colors with NSView-based rendering
                        ZStack {
                            GradientSwatchNSView(gradient: gradient, size: 22)
                                .frame(width: 22, height: 22)

                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(currentStrokeColor.color.opacity(currentStrokeOpacity))
                                .frame(width: 22, height: 22)

                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
                .help("Current Stroke Color: \(currentStrokeColor) (Opacity: \(Int(currentStrokeOpacity * 100))%) - Click to make active")
                .offset(x: 6, y: 6)  // Bottom-right offset
                // Fill color (foreground, top-left)
                Button {
                    document.activeColorTarget = .fill
                } label: {
                    if case .clear = currentFillColor {
                        ZStack {
                            // Checkerboard pattern for clear color
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
	                            
	                            Rectangle()
	                                .fill(Color.clear)
	                                .frame(width: 22, height: 22)
                            
                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }

                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else if case .gradient(let gradient) = currentFillColor {
                        // Handle gradient colors with NSView-based rendering
                        ZStack {
                            GradientSwatchNSView(gradient: gradient, size: 22)
                                .frame(width: 22, height: 22)

                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(currentFillColor.color.opacity(currentFillOpacity))
                                .frame(width: 22, height: 22)

                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
                .help("Current Fill Color: \(currentFillColor) (Opacity: \(Int(currentFillOpacity * 100))%) - Click to make active")
                .offset(x: -6, y: -6)  // Top-left offset
            }
			.frame(width: 28, height: 28)  // Total frame to contain both squares
            .padding(.bottom, 6)
            .padding(.top, 8)

            // Color Swatches
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(document.currentSwatches.enumerated()), id: \.offset) { index, color in
                    Button {
                        // Apply color to the currently active target (fill or stroke)
                        if document.activeColorTarget == .stroke {
                            selectedStrokeColor = color
                            document.defaultStrokeColor = color  // Set default for new shapes
                            applyStrokeColorToSelected(color)
                            Log.fileOperation("🎨 TOOLBAR: Set stroke color: \(color) (active target)", level: .info)
                            
                            // INK panel auto-updates from document bindings
                        } else {
                            selectedFillColor = color
                            document.defaultFillColor = color  // Set default for new shapes
                            applyFillColorToSelected(color)
                            Log.fileOperation("🎨 TOOLBAR: Set fill color: \(color) (active target)", level: .info)
                            
                            // INK panel auto-updates from document bindings
                        }
                    } label: {
                        ZStack {
                            // Base color (checkerboard for clear, normal color for others)
                            if case .clear = color {
                                ZStack {
                                    // Checkerboard pattern for clear color
                                    CheckerboardPattern(size: 2)
                                        .frame(width: 10, height: 10)
                                        .clipped()
                                    
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 10, height: 10)
                                        .border(Color.gray, width: 0.5)
                                    
                                    // Red slash overlay for clear color
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 10, y: 10))
                                    }
                                    .stroke(Color.red, lineWidth: 1)
                                    .frame(width: 10, height: 10)
                                }
                            } else if case .gradient(let gradient) = color {
                                // Handle gradient colors with NSView-based rendering
                                GradientSwatchNSView(gradient: gradient, size: 10)
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            } else {
                                Rectangle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("\(colorDescription(for: color)) (Click to apply to \(document.activeColorTarget == .fill ? "fill" : "stroke"))")
                }
            }
            .padding(.horizontal, 2)
            
            // Add Color Button
            Button {
                // Show persistent Ink HUD (Ink Color Mixer)
                appState.persistentInkHUD.show(document: document)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Add Custom Color")
            // HUD handles color selection and swatch additions; no sheet here
        }
    }
    
    private func applyFillColorToSelected(_ color: VectorColor) {
        // Apply to selected shapes
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if document.layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                        document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color)
                    } else {
                        document.layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                    }
                }
            }
        }
        
        // FIXED: Also apply to selected text objects - SAME LOGIC AS STROKE
        if !document.selectedTextIDs.isEmpty {
            if !document.selectedShapeIDs.isEmpty {
                // Don't save to undo stack twice
            } else {
                document.saveToUndoStack()
            }
            
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                    // MATCH STROKE LOGIC: Always ensure fill is active when setting fill color
                    document.textObjects[textIndex].typography.fillColor = color
                    document.textObjects[textIndex].typography.fillOpacity = document.defaultFillOpacity
                    document.textObjects[textIndex].updateBounds()

                }
            }
            document.objectWillChange.send()
        }
    }
    
    private func applyStrokeColorToSelected(_ color: VectorColor) {
        // Apply to selected shapes
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: document.defaultStrokeWidth, placement: document.defaultStrokePlacement, lineCap: document.defaultStrokeLineCap, lineJoin: document.defaultStrokeLineJoin, miterLimit: document.defaultStrokeMiterLimit, opacity: document.defaultStrokeOpacity)
                    } else {
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                    }
                }
            }
        }
        
        // FIXED: Also apply to selected text objects
        if !document.selectedTextIDs.isEmpty {
            if !document.selectedShapeIDs.isEmpty {
                // Don't save to undo stack twice
            } else {
                document.saveToUndoStack()
            }
            
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                    document.textObjects[textIndex].typography.hasStroke = true
                    document.textObjects[textIndex].typography.strokeColor = color
                    document.textObjects[textIndex].typography.strokeOpacity = document.defaultStrokeOpacity
                    document.textObjects[textIndex].updateBounds()
                }
            }
            document.objectWillChange.send()
        }
    }
    
    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb): return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk): return "CMYK(\(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))%, \(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))%, \(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))%, \(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))%)"
        case .hsb(let hsb): return "HSB(\(Int(hsb.hue))°, \(Int(hsb.saturation * 100))%, \(Int(hsb.brightness * 100))%)"
        case .pantone(let pantone): return "Pantone \(pantone.pantone)"
        case .spot(let spot): return "SPOT \(spot.number)"
        case .appleSystem(let systemColor): return "Apple \(systemColor.name.capitalized)"
        case .gradient(let gradient): 
            switch gradient {
            case .linear(_): return "Linear Gradient"
            case .radial(_): return "Radial Gradient"
            }
        }
    }
}



// Preview
struct VerticalToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VerticalToolbar(document: VectorDocument())
            .frame(height: 600)
    }
}

