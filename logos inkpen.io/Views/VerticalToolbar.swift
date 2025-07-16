//
//  VerticalToolbar.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct VerticalToolbar: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
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
                        
                        // print("🛠️ Switched to tool: \(tool.rawValue)")
                    } label: {
                        Image(systemName: tool.iconName)
                            .font(.system(size: 16))
                            .foregroundColor(document.currentTool == tool ? .white : .primary)
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
        case .directSelection:
            return "Direct Selection Tool (A) - Edit individual points and handles"
        case .convertAnchorPoint:
            return "Convert Anchor Point Tool (C) - Convert between smooth and corner points"
        case .bezierPen:
            return "Bezier Pen Tool (P) - Draw bezier curves and paths"
        case .font:
            return "Font Tool (T) - Add and edit text"
        case .line:
            return "Line Tool (L) - Draw straight lines"
        case .rectangle:
            return "Rectangle Tool (R) - Draw rectangles"
        case .circle:
            return "Circle Tool (C) - Draw circles and ellipses"
        case .star:
            return "Star Tool (S) - Draw star shapes"
        case .polygon:
            return "Polygon Tool - Draw polygon shapes"
        case .eyedropper:
            return "Eyedropper Tool (I) - Sample colors"
        case .hand:
            return "Hand Tool (H) - Pan the canvas"
        case .zoom:
            return "Zoom Tool (Z) - Zoom in and out"
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
            Image(systemName: tool.iconName)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .white : .primary)
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
    
    // FIXED: Show document's default colors (what will be used for new shapes)
    private var currentFillColor: VectorColor {
        // If shapes are selected, show their color, otherwise show default
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let fillColor = shape.fillStyle?.color {
            return fillColor
        }
        return document.defaultFillColor  // Show default color for new shapes
    }
    
    // FIXED: Show document's default colors (what will be used for new shapes)
    private var currentStrokeColor: VectorColor {
        // If shapes are selected, show their color, otherwise show default
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let strokeColor = shape.strokeStyle?.color {
            return strokeColor
        }
        return document.defaultStrokeColor  // Show default color for new shapes
    }
    
    // Get current fill opacity (from selected shapes or default)
    private var currentFillOpacity: Double {
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.fillStyle?.opacity {
            return opacity
        }
        return document.defaultFillOpacity
    }
    
    // Get current stroke opacity (from selected shapes or default)
    private var currentStrokeOpacity: Double {
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
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 22, height: 22)
                                .border(document.activeColorTarget == .stroke ? Color.blue : Color.gray, width: document.activeColorTarget == .stroke ? 2 : 0.5)
                            
                            Path { path in
                                path.move(to: CGPoint(x: 22, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: 22))
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
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 22, height: 22)
                                .border(document.activeColorTarget == .fill ? Color.blue : Color.gray, width: document.activeColorTarget == .fill ? 2 : 0.5)
                            
                            Path { path in
                                path.move(to: CGPoint(x: 22, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: 22))
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
                ForEach(Array(document.colorSwatches.enumerated()), id: \.offset) { index, color in
                    Button {
                        // Apply color to the currently active target (fill or stroke)
                        if document.activeColorTarget == .stroke {
                            selectedStrokeColor = color
                            document.defaultStrokeColor = color  // Set default for new shapes
                            applyStrokeColorToSelected(color)
                            // print("🎨 TOOLBAR: Set stroke color: \(color) (active target)")
                        } else {
                            selectedFillColor = color
                            document.defaultFillColor = color  // Set default for new shapes
                            applyFillColorToSelected(color)
                            // print("🎨 TOOLBAR: Set fill color: \(color) (active target)")
                        }
                    } label: {
                        ZStack {
                            // Base color (gray background for clear, normal color for others)
                            if case .clear = color {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            } else {
                                Rectangle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            }
                            
                            // Red slash overlay for clear color
                            if case .clear = color {
                                Path { path in
                                    path.move(to: CGPoint(x: 10, y: 0))
                                    path.addLine(to: CGPoint(x: 0, y: 10))
                                }
                                .stroke(Color.red, lineWidth: 1)
                                .frame(width: 10, height: 10)
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
        
        // FIXED: Also apply to selected text objects
        if !document.selectedTextIDs.isEmpty {
            if !document.selectedShapeIDs.isEmpty {
                // Don't save to undo stack twice
            } else {
                document.saveToUndoStack()
            }
            
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
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
        case .pantone(let pantone): return "Pantone \(pantone.number)"
        case .appleSystem(let systemColor): return "Apple \(systemColor.name.capitalized)"
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
