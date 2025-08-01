//
//  VerticalToolbar.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

// MARK: - Star Variants
enum StarVariant: String, CaseIterable {
    case threePoint = "3-Point Star"
    case fourPoint = "4-Point Star" 
    case fivePoint = "5-Point Star"
    case sixPoint = "6-Point Star"
    case eightPoint = "8-Point Star"
    
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
        case .eightPoint:
            EightPointStarIcon(isSelected: isSelected)
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
            // Create a 3-pointed curved star like the Mercedes logo in your image
            let center = CGPoint(x: 10, y: 10)
            let radius: CGFloat = 7
            
            // Top point
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            
            // Curve to bottom right
            path.addQuadCurve(
                to: CGPoint(x: center.x + radius * 0.866, y: center.y + radius * 0.5),
                control: CGPoint(x: center.x + radius * 0.3, y: center.y - radius * 0.3)
            )
            
            // Curve to bottom left
            path.addQuadCurve(
                to: CGPoint(x: center.x - radius * 0.866, y: center.y + radius * 0.5),
                control: CGPoint(x: center.x, y: center.y + radius * 0.8)
            )
            
            // Curve back to top
            path.addQuadCurve(
                to: CGPoint(x: center.x, y: center.y - radius),
                control: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.3)
            )
        }
        .stroke(Color.primary, lineWidth: 1.5)
        .frame(width: 20, height: 20)
    }
}

// 4-Point Star (diamond/cross shaped)
struct FourPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Create a 4-pointed star like the second image
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8
            let innerRadius: CGFloat = 3
            
            // Start at top
            path.move(to: CGPoint(x: center.x, y: center.y - outerRadius))
            path.addLine(to: CGPoint(x: center.x + innerRadius, y: center.y - innerRadius))
            
            // Right point
            path.addLine(to: CGPoint(x: center.x + outerRadius, y: center.y))
            path.addLine(to: CGPoint(x: center.x + innerRadius, y: center.y + innerRadius))
            
            // Bottom point
            path.addLine(to: CGPoint(x: center.x, y: center.y + outerRadius))
            path.addLine(to: CGPoint(x: center.x - innerRadius, y: center.y + innerRadius))
            
            // Left point
            path.addLine(to: CGPoint(x: center.x - outerRadius, y: center.y))
            path.addLine(to: CGPoint(x: center.x - innerRadius, y: center.y - innerRadius))
            
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: 1.5)
        .frame(width: 20, height: 20)
    }
}

// 5-Point Star (classic star)
struct FivePointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        // Use SF Symbol as fallback since custom path is complex
        Image(systemName: "star")
            .font(.system(size: 16))
            .foregroundColor(.primary)
            .frame(width: 20, height: 20)
    }
}

// 6-Point Star (Star of David style)
struct SixPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Create a 6-pointed star like the third image
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8
            let innerRadius: CGFloat = 4
            
            for i in 0..<6 {
                let angle = Double(i) * .pi / 3 - .pi / 2 // Start from top
                let nextAngle = Double(i + 1) * .pi / 3 - .pi / 2
                
                let outerPoint = CGPoint(
                    x: center.x + outerRadius * cos(angle),
                    y: center.y + outerRadius * sin(angle)
                )
                
                let innerPoint = CGPoint(
                    x: center.x + innerRadius * cos(nextAngle - .pi / 6),
                    y: center.y + innerRadius * sin(nextAngle - .pi / 6)
                )
                
                if i == 0 {
                    path.move(to: outerPoint)
                } else {
                    path.addLine(to: outerPoint)
                }
                path.addLine(to: innerPoint)
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: 1.5)
        .frame(width: 20, height: 20)
    }
}

// 8-Point Star (compass rose style)
struct EightPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Create an 8-pointed star like the fourth image
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8
            let innerRadius: CGFloat = 4
            
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4 - .pi / 2 // Start from top
                let nextAngle = Double(i + 1) * .pi / 4 - .pi / 2
                
                let outerPoint = CGPoint(
                    x: center.x + outerRadius * cos(angle),
                    y: center.y + outerRadius * sin(angle)
                )
                
                let innerPoint = CGPoint(
                    x: center.x + innerRadius * cos(nextAngle - .pi / 8),
                    y: center.y + innerRadius * sin(nextAngle - .pi / 8)
                )
                
                if i == 0 {
                    path.move(to: outerPoint)
                } else {
                    path.addLine(to: outerPoint)
                }
                path.addLine(to: innerPoint)
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: 1.5)
        .frame(width: 20, height: 20)
    }
}

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

struct VerticalToolbar: View {
    @ObservedObject var document: VectorDocument
    @StateObject private var starHUDManager = StarToolHUDManager()

    // MARK: - Star Tool HUD Functions
    
    private func showStarHUD() {
        // Use the HUD manager to show the HUD with proper positioning
        starHUDManager.showHUD()
    }

    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                // Drawing Tools
                ToolSection(title: "Drawing") {
                    ForEach(DrawingTool.allCases, id: \.self) { tool in
                        Button {
                            // SAFE CURSOR MANAGEMENT - Limited cursor pops to prevent infinite loops
                            var popCount = 0
                            while NSCursor.current != NSCursor.arrow && popCount < 10 {
                                NSCursor.pop()
                                popCount += 1
                            }
                            
                            // If still not arrow cursor, force reset
                            if NSCursor.current != NSCursor.arrow {
                                NSCursor.arrow.set()
                            }
                            
                            document.currentTool = tool
                            tool.cursor.push()
                            
                            print("🛠️ Switched to tool: \(tool.rawValue)")
                        } label: {
                            Group {
                                if tool == .shear {
                                    // Use custom skewed rectangle icon for shear tool
                                    SkewedRectangleIcon(isSelected: document.currentTool == tool)
                                } else if tool == .star {
                                    // Use selected star variant custom icon
                                                                starHUDManager.selectedVariant.iconView(
                                isSelected: document.currentTool == tool,
                                color: document.currentTool == tool ? .white : .primary
                            )
                                } else {
                                    // Use SF Symbols for all other tools
                                    Image(systemName: tool.iconName)
                                        .font(.system(size: 16))
                                        .foregroundColor(document.currentTool == tool ? .white : .primary)
                                }
                            }
                            .frame(width: 32, height: 32)
                            .background(
                                document.currentTool == tool 
                                ? Color.blue.opacity(0.8)
                                : Color.clear
                            )
                            .cornerRadius(4)
                            .contentShape(Rectangle()) // Extend hit area to match entire button area
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(toolTooltip(for: tool))
                        .if(tool == .star) { view in
                            view.background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            // Store the button's frame for HUD positioning
                                            let globalFrame = geometry.frame(in: .global)
                                            starHUDManager.starButtonFrame = globalFrame
                                        }
                                        .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                                            // Update frame if it changes (e.g., during scrolling)
                                            starHUDManager.starButtonFrame = newFrame
                                        }
                                }
                            )
                            .highPriorityGesture(
                                TapGesture()
                                    .onEnded { _ in
                                        // SAFE CURSOR MANAGEMENT - Limited cursor pops to prevent infinite loops
                                        var popCount = 0
                                        while NSCursor.current != NSCursor.arrow && popCount < 10 {
                                            NSCursor.pop()
                                            popCount += 1
                                        }
                                        
                                        // If still not arrow cursor, force reset
                                        if NSCursor.current != NSCursor.arrow {
                                            NSCursor.arrow.set()
                                        }
                                        
                                        document.currentTool = tool
                                        tool.cursor.push()
                                        
                                        print("⭐ Star tool tap detected - tool selected!")
                                    }
                            )
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        // Long press completed - show HUD window
                                        showStarHUD()
                                        print("⭐ Star tool long press - showing HUD!")
                                    }
                            )
                        }
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
    

    
    private func toolTooltip(for tool: DrawingTool) -> String {
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
            return "Marker Tool - Draw with circular felt-tip marker strokes"
        case .font:
            return "Font Tool (T) - Add and edit text"
        case .line:
            return "Line Tool (L) - Draw straight lines"
        case .rectangle:
            return "Rectangle Tool (R) - Draw rectangles"
        case .circle:
            return "Circle Tool (C) - Draw circles and ellipses"
        case .star:
            return "Star Tool - Draw \(starHUDManager.selectedVariant.rawValue) (Long press for more variants)"
        case .polygon:
            return "Polygon Tool - Draw polygon shapes"
        case .eyedropper:
            return "Eyedropper Tool (I) - Sample colors"
        case .hand:
            return "Hand Tool (H) - Pan the canvas"
        case .zoom:
            return "Zoom Tool (Z) - Zoom in and out"
        case .warp:
            return "Warp Tool"
        case .gradient:
            return "Gradient Tool (G) - Edit gradient origin and focal points"

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
           let fillColor = shape.fillStyle?.color {
            return fillColor
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
            // Current Fill and Stroke Colors - Adobe Illustrator Style (overlapping squares)
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
                                .border(document.activeColorTarget == .stroke ? Color.blue : Color.gray, width: document.activeColorTarget == .stroke ? 2 : 0.5)
                            
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else {
                        Rectangle()
                            .fill(currentStrokeColor.color.opacity(currentStrokeOpacity))
                            .frame(width: 22, height: 22)
                            .border(document.activeColorTarget == .stroke ? Color.blue : Color.gray, width: document.activeColorTarget == .stroke ? 2 : 0.5)
                    }
                }
                .buttonStyle(PlainButtonStyle())
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
                                .border(document.activeColorTarget == .fill ? Color.blue : Color.gray, width: document.activeColorTarget == .fill ? 2 : 0.5)
                            
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else {
                        Rectangle()
                            .fill(currentFillColor.color.opacity(currentFillOpacity))
                            .frame(width: 22, height: 22)
                            .border(document.activeColorTarget == .fill ? Color.blue : Color.gray, width: document.activeColorTarget == .fill ? 2 : 0.5)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Current Fill Color: \(currentFillColor) (Opacity: \(Int(currentFillOpacity * 100))%) - Click to make active")
                .offset(x: -6, y: -6)  // Top-left offset
            }
            .frame(width: 34, height: 34)  // Total frame to contain both squares
            .padding(.bottom, 8)
            
            // Color Swatches
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(document.currentSwatches.enumerated()), id: \.offset) { index, color in
                    Button {
                        // Apply color to the currently active target (fill or stroke)
                        if document.activeColorTarget == .stroke {
                            selectedStrokeColor = color
                            document.defaultStrokeColor = color  // Set default for new shapes
                            applyStrokeColorToSelected(color)
                            print("🎨 TOOLBAR: Set stroke color: \(color) (active target)")
                        } else {
                            selectedFillColor = color
                            document.defaultFillColor = color  // Set default for new shapes
                            applyFillColorToSelected(color)
                            print("🎨 TOOLBAR: Set fill color: \(color) (active target)")
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
                showingColorPicker = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Add Custom Color")
            .sheet(isPresented: $showingColorPicker) {
                ColorPickerModal(
                    document: document,
                    title: "Add Color", 
                    onColorSelected: { color in
                        // Apply to active target
                        if document.activeColorTarget == .stroke {
                            document.defaultStrokeColor = color
                            applyStrokeColorToSelected(color)
                        } else {
                            document.defaultFillColor = color
                            applyFillColorToSelected(color)
                        }
                        // ONLY add to swatches when explicitly adding via "Add Color" button
                        document.addColorSwatch(color)
                    }
                )
            }
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
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, opacity: 1.0)
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
