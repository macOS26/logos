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
                        
                        print("🛠️ Switched to tool: \(tool.rawValue)")
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
        case .text:
            return "Text Tool (T) - Add text"
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
    
    var body: some View {
        VStack(spacing: 4) {
            // Current Fill and Stroke Colors
            HStack(spacing: 4) {
                Button {
                    applyFillColorToSelected(currentFillColor)
                } label: {
                    Rectangle()
                        .fill(currentFillColor.color)
                        .frame(width: 24, height: 24)
                        .border(Color.gray, width: 1)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Current Fill Color (Click to apply to selected objects)")
                
                Button {
                    applyStrokeColorToSelected(currentStrokeColor)
                } label: {
                    Rectangle()
                        .fill(currentStrokeColor.color)
                        .frame(width: 24, height: 24)
                        .border(Color.gray, width: 1)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Current Stroke Color (Click to apply to selected objects)")
            }
            .padding(.horizontal, 4)
            
            // Color Swatches
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(document.colorSwatches.enumerated()), id: \.offset) { index, color in
                    Button {
                        // FIXED: Update default colors for future shapes AND apply to selected
                        if NSEvent.modifierFlags.contains(.option) {
                            selectedStrokeColor = color
                            document.defaultStrokeColor = color  // Set default for new shapes
                            applyStrokeColorToSelected(color)
                            print("🎨 Set default stroke color: \(color)")
                        } else {
                            selectedFillColor = color
                            document.defaultFillColor = color  // Set default for new shapes
                            applyFillColorToSelected(color)
                            print("🎨 Set default fill color: \(color)")
                        }
                    } label: {
                        Rectangle()
                            .fill(color.color)
                            .frame(width: 10, height: 10)
                            .border(Color.gray, width: 0.5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("\(colorDescription(for: color)) (Click for fill, Option+Click for stroke)")
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
                CustomColorPicker(document: document)
            }
        }
    }
    
    private func applyFillColorToSelected(_ color: VectorColor) {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
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
    
    private func applyStrokeColorToSelected(_ color: VectorColor) {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
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
    
    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb): return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk): return "CMYK(\(Int(cmyk.cyan * 100))%, \(Int(cmyk.magenta * 100))%, \(Int(cmyk.yellow * 100))%, \(Int(cmyk.black * 100))%)"
        case .pantone(let pantone): return "Pantone \(pantone.number)"
        }
    }
}

struct CustomColorPicker: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedColor = Color.red
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Color Picker
                ColorPicker("Select Color", selection: $selectedColor)
                    .labelsHidden()
                    .scaleEffect(2.0)
                    .frame(height: 200)
                
                // Add to Swatches Button
                Button("Add to Swatches") {
                    let rgbColor = RGBColor(
                        red: selectedColor.components.red,
                        green: selectedColor.components.green,
                        blue: selectedColor.components.blue,
                        alpha: selectedColor.components.alpha
                    )
                    let vectorColor = VectorColor.rgb(rgbColor)
                    document.addColorSwatch(vectorColor)
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Color")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(width: 300, height: 400)
    }
}

// Preview
struct VerticalToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VerticalToolbar(document: VectorDocument())
            .frame(height: 600)
    }
}