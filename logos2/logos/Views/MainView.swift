//
//  MainView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var document = VectorDocument()
    @State private var showingDocumentSettings = false
    @State private var showingExportDialog = false
    @State private var showingColorPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content Area
            HStack(spacing: 0) {
                // Left Toolbar - Fixed width, hugs left
                VerticalToolbar(document: document)
                    .frame(width: 48)
                
                // Center Drawing Area - Flexible width
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Drawing canvas area
                        ZStack {
                            // Main Drawing Canvas
                            DrawingCanvas(document: document)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, document.showRulers ? 20 : 0)
                                .padding(.leading, document.showRulers ? 20 : 0)
                            
                            // Rulers
                            RulersView(document: document, geometry: geometry)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Status Bar at bottom
                        StatusBar(document: document)
                            .frame(height: 24)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right Panel - Fixed width, hugs right
                RightPanel(document: document)
                    .frame(width: 280)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            MainToolbarContent(
                document: document,
                showingDocumentSettings: $showingDocumentSettings,
                showingExportDialog: $showingExportDialog,
                showingColorPicker: $showingColorPicker
            )
        }
        .sheet(isPresented: $showingDocumentSettings) {
            DocumentSettingsView(document: document)
        }
        .sheet(isPresented: $showingExportDialog) {
            ExportView(document: document)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(document: document)
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear {
            setupDocument()
        }
    }
    
    private func setupDocument() {
        // Add some sample shapes for demonstration
        let rect = VectorShape.rectangle(at: CGPoint(x: 100, y: 100), size: CGSize(width: 150, height: 100))
        let circle = VectorShape.circle(center: CGPoint(x: 300, y: 150), radius: 50)
        let star = VectorShape.star(center: CGPoint(x: 200, y: 300), outerRadius: 40, innerRadius: 20)
        
        document.addShape(rect)
        document.addShape(circle)
        document.addShape(star)
    }
}

struct MainToolbarContent: ToolbarContent {
    @ObservedObject var document: VectorDocument
    @Binding var showingDocumentSettings: Bool
    @Binding var showingExportDialog: Bool
    @Binding var showingColorPicker: Bool
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // File Operations
            Menu {
                Button("New Document") {
                    // Create new document
                }
                
                Button("Open Document") {
                    // Open document
                }
                
                Divider()
                
                Button("Save") {
                    // Save document
                }
                
                Button("Save As...") {
                    // Save document as
                }
                
                Divider()
                
                Button("Export...") {
                    showingExportDialog = true
                }
                
            } label: {
                Image(systemName: "doc.text")
            }
            .help("File Operations")
            
            // Edit Operations
            Button {
                document.undo()
            } label: {
                Image(systemName: "arrow.uturn.left")
            }
            .help("Undo")
            .disabled(document.undoStack.isEmpty)
            
            Button {
                document.redo()
            } label: {
                Image(systemName: "arrow.uturn.right")
            }
            .help("Redo")
            .disabled(document.redoStack.isEmpty)
            
            // Shape Operations
            Button {
                document.duplicateSelectedShapes()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Duplicate")
            .disabled(document.selectedShapeIDs.isEmpty)
            
            Button {
                document.removeSelectedShapes()
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete")
            .disabled(document.selectedShapeIDs.isEmpty)
            
            // View Controls
            Button {
                document.viewMode = document.viewMode == .color ? .keyline : .color
            } label: {
                Image(systemName: document.viewMode.iconName)
                    .foregroundColor(document.viewMode == .keyline ? .orange : .primary)
            }
            .help(document.viewMode.description)
            
            Button {
                document.showRulers.toggle()
            } label: {
                Image(systemName: document.showRulers ? "ruler.fill" : "ruler")
            }
            .help("Toggle Rulers")
            
            Button {
                document.snapToGrid.toggle()
            } label: {
                Image(systemName: document.snapToGrid ? "grid.circle.fill" : "grid.circle")
            }
            .help("Toggle Snap to Grid")
            
            // Zoom Controls
            Menu {
                Button("Zoom In") {
                    document.zoomLevel = min(10.0, document.zoomLevel * 1.25)
                }
                
                Button("Zoom Out") {
                    document.zoomLevel = max(0.1, document.zoomLevel / 1.25)
                }
                
                Button("Zoom to Fit") {
                    document.zoomLevel = 1.0
                    document.canvasOffset = .zero
                }
                
                Button("Actual Size") {
                    document.zoomLevel = 1.0
                }
                
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("Zoom Controls")
            
            // Document Settings
            Button {
                showingDocumentSettings = true
            } label: {
                Image(systemName: "gear")
            }
            .help("Document Settings")
            
            // Color Picker
            Button {
                showingColorPicker = true
            } label: {
                Image(systemName: "paintpalette")
            }
            .help("Color Picker")
            
        }
        
        ToolbarItem(placement: .status) {
            Text("Zoom: \(Int(document.zoomLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct StatusBar: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        HStack {
            // Current Tool
            Text("Tool: \(document.currentTool.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Selection Info
            if document.selectedShapeIDs.isEmpty {
                Text("No selection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(document.selectedShapeIDs.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Document Info
            Text("Size: \(Int(document.settings.width))×\(Int(document.settings.height)) \(document.settings.unit.abbreviation)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Zoom Level
            Text("Zoom: \(Int(document.zoomLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .top
        )
    }
}

struct DocumentSettingsView: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Document Size")) {
                    HStack {
                        Text("Width:")
                        TextField("Width", value: $document.settings.width, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Height:")
                        TextField("Height", value: $document.settings.height, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Picker("Unit", selection: $document.settings.unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }
                
                Section(header: Text("Color")) {
                    Picker("Color Mode", selection: $document.settings.colorMode) {
                        ForEach(ColorMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                Section(header: Text("Grid")) {
                    Toggle("Show Grid", isOn: $document.settings.showGrid)
                    
                    HStack {
                        Text("Grid Spacing:")
                        TextField("Spacing", value: $document.settings.gridSpacing, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Toggle("Snap to Grid", isOn: $document.settings.snapToGrid)
                }
                
                Section(header: Text("View")) {
                    Toggle("Show Rulers", isOn: $document.settings.showRulers)
                    
                    HStack {
                        Text("Resolution:")
                        TextField("DPI", value: $document.settings.resolution, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("DPI")
                    }
                }
            }
            .navigationTitle("Document Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}

struct ExportView: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    @State private var exportFormat: ExportFormat = .svg
    @State private var exportQuality: Double = 1.0
    
    enum ExportFormat: String, CaseIterable {
        case svg = "SVG"
        case pdf = "PDF"
        case png = "PNG"
        case jpeg = "JPEG"
        
        var fileExtension: String {
            switch self {
            case .svg: return "svg"
            case .pdf: return "pdf"
            case .png: return "png"
            case .jpeg: return "jpg"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if exportFormat == .png || exportFormat == .jpeg {
                    Section(header: Text("Quality")) {
                        Slider(value: $exportQuality, in: 0.1...1.0)
                        Text("Quality: \(Int(exportQuality * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Export Options")) {
                    Text("Size: \(Int(document.settings.sizeInPoints.width))×\(Int(document.settings.sizeInPoints.height)) points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Layers: \(document.layers.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let totalShapes = document.layers.reduce(0) { $0 + $1.shapes.count }
                    Text("Shapes: \(totalShapes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Export Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        exportDocument()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private func exportDocument() {
        // Implementation for export functionality
        print("Exporting document as \(exportFormat.rawValue)")
        // This would integrate with file system APIs for actual export
    }
}

struct ColorPickerView: View {
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
                
                // Color Mode Picker
                Picker("Color Mode", selection: $document.settings.colorMode) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.iconName)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                // Current Swatches
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: 6), spacing: 8) {
                    ForEach(Array(document.colorSwatches.enumerated()), id: \.offset) { index, color in
                        Rectangle()
                            .fill(color.color)
                            .frame(width: 40, height: 40)
                            .border(Color.gray, width: 1)
                            .onTapGesture {
                                selectedColor = color.color
                            }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Color Picker")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Swatches") {
                        addColorToSwatches()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
    
    private func addColorToSwatches() {
        let rgbColor = RGBColor(red: selectedColor.components.red, green: selectedColor.components.green, blue: selectedColor.components.blue)
        let vectorColor = VectorColor.rgb(rgbColor)
        document.addColorSwatch(vectorColor)
    }
}

// Helper extension for Color components
extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        let nsColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}

// Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}