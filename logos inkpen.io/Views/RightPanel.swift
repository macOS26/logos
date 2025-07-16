//
//  RightPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct RightPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var selectedTab: PanelTab = .layers
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            PanelTabBar(selectedTab: $selectedTab)
            
            // Content
            Group {
                switch selectedTab {
                case .layers:
                    LayersPanel(document: document)
                case .properties:
                    StrokeFillPanel(document: document)
                case .color:
                    ColorPanel(document: document)
                case .pathOps:
                    PathOperationsPanel(document: document)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .leading
        )
        .onAppear {
            // PROFESSIONAL PANEL SWITCHING (Adobe Illustrator Standards)
            NotificationCenter.default.addObserver(forName: .switchToPanel, object: nil, queue: .main) { notification in
                if let panelTab = notification.object as? PanelTab {
                    selectedTab = panelTab
                    print("🎨 Menu: Switched to panel: \(panelTab.rawValue)")
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
}













// PropertiesPanel removed - using StrokeFillPanel instead

// Old property structures removed - using StrokeFillPanel instead

struct ColorPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var searchText = ""
    @State private var showingPantoneSearch = false
    let onColorSelected: ((VectorColor) -> Void)?
    
    init(document: VectorDocument, onColorSelected: ((VectorColor) -> Void)? = nil) {
        self.document = document
        self.onColorSelected = onColorSelected
    }
    
    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                Text("Color")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
            // Color Mode Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Color Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                
                Picker("Color Mode", selection: Binding(
                    get: { document.settings.colorMode },
                    set: { newMode in
                        document.settings.colorMode = newMode
                        document.updateColorSwatchesForMode()
                    }
                )) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.iconName)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
            }
            .padding(.horizontal, 12)
            
            // Mode-specific input sections
            if document.settings.colorMode == .pantone {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Pantone Colors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Enter Pantone number (e.g. 032 C)", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.caption)
                        
                        Button("Search") {
                            searchPantoneColor(searchText)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
            } else if document.settings.colorMode == .cmyk {
                CMYKInputSection(document: document)
                        .padding(.horizontal, 12)
                }
                
            // Color Mode Specific Information
            HStack {
                Text(colorModeDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            
            // Color Swatches
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 4), count: 8), spacing: 4) {
                                    ForEach(Array(filteredColors.enumerated()), id: \.offset) { index, color in
                    Button {
                        selectColor(color)
                    } label: {
                        ZStack {
                            renderColorSwatchRightPanel(color, width: 30, height: 30, cornerRadius: 0, borderWidth: 1)
                            
                            // Show Pantone number for Pantone colors (if not clear)
                            if case .pantone = color {
                                overlayText(for: color)
                            }
                        }
                    }
                        .buttonStyle(PlainButtonStyle())
                        .help(colorDescription(for: color))
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Add Color Button
            HStack {
                if document.settings.colorMode == .pantone {
                    Button("Browse Pantone Library") {
                        showingPantoneSearch = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                } else {
                    Button("Add Custom Color") {
                        showingPantoneSearch = true // Will be used for general color picker
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .sheet(isPresented: $showingPantoneSearch) {
            PantoneColorPickerSheet(document: document)
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    private var colorModeDescription: String {
        switch document.settings.colorMode {
        case .rgb:
            return "RGB colors for screen display"
        case .cmyk:
            return "CMYK colors for print production"
        case .pantone:
            return "Pantone spot colors for professional printing"
        }
    }
    
    private var filteredColors: [VectorColor] {
        if searchText.isEmpty {
            return document.colorSwatches
        } else {
            return document.colorSwatches.filter { color in
                colorDescription(for: color).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func selectColor(_ color: VectorColor) {
        // Apply color to selected objects
        if !document.selectedShapeIDs.isEmpty {
            // Apply to shapes
            guard let layerIndex = document.selectedLayerIndex else { return }
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if NSEvent.modifierFlags.contains(.option) {
                        // Option+Click = stroke color
                        if document.layers[layerIndex].shapes[shapeIndex].strokeStyle != nil {
                            document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                        } else {
                            document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: 1.0)
                        }
                    } else {
                        // Regular click = fill color
                        if document.layers[layerIndex].shapes[shapeIndex].fillStyle != nil {
                            document.layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                        } else {
                            document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color)
                        }
                    }
                }
            }
        }
        
        if !document.selectedTextIDs.isEmpty {
            // Apply to text
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                    document.textObjects[textIndex].typography.fillColor = color
                }
            }
        }
        
        onColorSelected?(color)
    }
    
    private func searchPantoneColor(_ searchQuery: String) {
        let allPantoneColors = ColorManagement.loadPantoneColors()
        
        if let foundColor = allPantoneColors.first(where: { 
            $0.number.localizedCaseInsensitiveContains(searchQuery) ||
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }) {
            let pantoneColor = VectorColor.pantone(foundColor)
            // Only add to swatches when explicitly searching and finding
            if !document.colorSwatches.contains(pantoneColor) {
                document.addColorSwatch(pantoneColor)
            }
            searchText = ""
        }
    }
    
    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb): 
            return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk): 
            return "CMYK(\(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))%, \(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))%, \(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))%, \(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))%)"
        case .pantone(let pantone): 
            return "PANTONE \(pantone.number) - \(pantone.name)"
        case .appleSystem(let systemColor): 
            return "Apple \(systemColor.name.capitalized)"
        }
    }
    
    @ViewBuilder
    private func overlayText(for color: VectorColor) -> some View {
        if case .pantone(let pantone) = color {
            Text(pantone.number)
                .font(.system(size: 6))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1)
                .lineLimit(1)
        }
    }
}

struct PathOperationsPanel: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Pathfinder")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                // Info button
                Button {
                    // Show pathfinder help
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Adobe Illustrator Pathfinder Operations")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Shape Modes Section (Adobe Illustrator standard)
                VStack(alignment: .leading, spacing: 8) {
                Text("Shape Modes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach([PathfinderOperation.unite, .minusFront, .intersect, .exclude], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Pathfinder Effects Section (Adobe Illustrator standard)
            VStack(alignment: .leading, spacing: 8) {
                Text("Pathfinder Effects")
                        .font(.caption)
                    .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach([PathfinderOperation.divide, .trim, .merge, .crop, .dieline, .minusBack], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // PROFESSIONAL OFFSET PATH SECTION (Adobe Illustrator / FreeHand / CorelDRAW Standards)
            ProfessionalOffsetPathSection(document: document)
            
            // Path Cleanup Section (Professional Tools)
            VStack(alignment: .leading, spacing: 8) {
                Text("Path Cleanup")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                VStack(spacing: 6) {
                    Button("Clean Duplicate Points") {
                        if !document.selectedShapeIDs.isEmpty {
                            ProfessionalPathOperations.cleanupSelectedShapesDuplicates(document, tolerance: 5.0)
                        } else {
                            ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Remove overlapping points and merge their curve data smoothly (⌘⇧K)")
                    .disabled(document.layers.flatMap(\.shapes).isEmpty)
                    
                    Button("Clean All Paths") {
                        ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 1.0)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Clean duplicate points in all shapes in the document (⌘⌥K)")
                    .disabled(document.layers.flatMap(\.shapes).isEmpty)
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
        }
    }
    
    private func canPerformOperation(_ operation: PathfinderOperation) -> Bool {
        let selectedShapes = document.getSelectedShapes()
        let paths = selectedShapes.map { $0.path.cgPath }
        return ProfessionalPathOperations.canPerformOperation(operation, on: paths)
    }
    
    private func performPathfinderOperation(_ operation: PathfinderOperation) {
        print("🎨 PROFESSIONAL ADOBE ILLUSTRATOR pathfinder operation: \(operation.rawValue)")
        
        // Get selected shapes in correct STACKING ORDER (Adobe Illustrator standard)
        let selectedShapes = document.getSelectedShapesInStackingOrder()
        guard !selectedShapes.isEmpty else {
            print("❌ No shapes selected for pathfinder operation")
            return
        }
        
        print("📚 STACKING ORDER: Processing \(selectedShapes.count) shapes")
        for (index, shape) in selectedShapes.enumerated() {
            print("  \(index): \(shape.name) (bottom→top)")
        }
        
        // Convert shapes to CGPaths
        let paths = selectedShapes.map { $0.path.cgPath }
        
        // Validate operation can be performed
        guard ProfessionalPathOperations.canPerformOperation(operation, on: paths) else {
            print("❌ Cannot perform \(operation.rawValue) on selected shapes")
            return
        }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        // Perform the operation using EXACT ADOBE ILLUSTRATOR BEHAVIOR
        var resultShapes: [VectorShape] = []
        
        switch operation {
        // SHAPE MODES (Adobe Illustrator)
        case .unite:
            // UNITE: Combines all shapes, result takes color of TOPMOST object
            if let unitedPath = ProfessionalPathOperations.unite(paths) {
                let topmostShape = selectedShapes.last! // Last in array = topmost in stacking order
                let unitedShape = VectorShape(
                    name: "United Shape",
                    path: VectorPath(cgPath: unitedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [unitedShape]
                print("✅ UNITE: Created unified shape with topmost object's color")
            }
            
        case .minusFront:
            // MINUS FRONT: Front objects subtract from back object, result takes color of BACK object
            guard selectedShapes.count >= 2 else { 
                print("❌ MINUS FRONT requires at least 2 shapes")
                return 
            }
            
            let backShape = selectedShapes.first!    // First in array = bottommost = back
            let frontShapes = Array(selectedShapes.dropFirst()) // All others = front
            
            print("🔪 MINUS FRONT: Back shape '\(backShape.name)' - Front shapes: \(frontShapes.map { $0.name })")
            
            var resultPath = backShape.path.cgPath
            
            // Subtract each front shape from the result
            for frontShape in frontShapes {
                if let subtractedPath = ProfessionalPathOperations.minusFront(frontShape.path.cgPath, from: resultPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(frontShape.name)' from result")
                }
            }
            
            // Result takes style of BACK object (Adobe Illustrator standard)
            let resultShape = VectorShape(
                name: "Minus Front Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: backShape.strokeStyle,
                fillStyle: backShape.fillStyle,
                transform: .identity,
                opacity: backShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ MINUS FRONT: Result takes back object's color (\(backShape.name))")
            
        case .intersect:
            // INTERSECT: Keep only overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                print("❌ INTERSECT requires exactly 2 shapes")
                return
            }
            
            if let intersectedPath = ProfessionalPathOperations.intersect(paths[0], paths[1]) {
                let topmostShape = selectedShapes.last! // Last = topmost
                let intersectedShape = VectorShape(
                    name: "Intersected Shape",
                    path: VectorPath(cgPath: intersectedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [intersectedShape]
                print("✅ INTERSECT: Result takes topmost object's color (\(topmostShape.name))")
            }
            
        case .exclude:
            // EXCLUDE: Remove overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                print("❌ EXCLUDE requires exactly 2 shapes")
                return
            }
            
            let excludedPaths = ProfessionalPathOperations.exclude(paths[0], paths[1])
            let topmostShape = selectedShapes.last! // Last = topmost
            
            for (index, excludedPath) in excludedPaths.enumerated() {
                let excludedShape = VectorShape(
                    name: "Excluded Shape \(index + 1)",
                    path: VectorPath(cgPath: excludedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes.append(excludedShape)
            }
            print("✅ EXCLUDE: Created \(resultShapes.count) pieces with topmost object's color (\(topmostShape.name))")
        
        // PATHFINDER EFFECTS (Adobe Illustrator) - These retain original colors
        case .divide:
            // DIVIDE: Break into separate objects, each retains original color
            let dividedPaths = ProfessionalPathOperations.divide(paths)
            
            for (index, dividedPath) in dividedPaths.enumerated() {
                // Determine which original shape this divided piece belongs to
                let originalShape = determineOriginalShapeForDividedPiece(dividedPath, from: selectedShapes)
                
                let dividedShape = VectorShape(
                    name: "Divided Piece \(index + 1)",
                    path: VectorPath(cgPath: dividedPath),
                    strokeStyle: originalShape.strokeStyle,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(dividedShape)
            }
            print("✅ DIVIDE: Created \(resultShapes.count) pieces with original colors")
            
        case .trim:
            // TRIM: Remove overlapping areas, objects retain original colors, removes strokes
            let trimmedResults = ProfessionalPathOperations.professionalTrimWithShapeTracking(paths)
            
            // Adobe Illustrator Trim: Each resulting piece maintains the color of its original shape
            var shapeCounters: [Int: Int] = [:]
            
            for (trimmedPath, originalShapeIndex) in trimmedResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                // Track how many pieces we've created from this original shape
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex]!
                
                let trimmedShape = VectorShape(
                    name: pieceNumber > 1 ? "Trimmed \(originalShape.name) (\(pieceNumber))" : "Trimmed \(originalShape.name)",
                    path: VectorPath(cgPath: trimmedPath),
                    strokeStyle: nil, // TRIM removes strokes (Adobe Illustrator standard)
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(trimmedShape)
            }
            print("✅ TRIM: Created \(resultShapes.count) trimmed shapes, removed strokes")
            
        case .merge:
            // MERGE: Like trim but merges objects of same color, removes strokes
            let mergedPaths = ProfessionalPathOperations.merge(paths)
            
            for (index, mergedPath) in mergedPaths.enumerated() {
                // For merge, we assume same color objects get merged into one
                let representativeShape = selectedShapes.first!
                
                let mergedShape = VectorShape(
                    name: "Merged Shape \(index + 1)",
                    path: VectorPath(cgPath: mergedPath),
                    strokeStyle: nil, // MERGE removes strokes (Adobe Illustrator standard)
                    fillStyle: representativeShape.fillStyle,
                    transform: .identity,
                    opacity: representativeShape.opacity
                )
                resultShapes.append(mergedShape)
            }
            print("✅ MERGE: Created \(resultShapes.count) merged shapes, removed strokes")
            
        case .crop:
            // CROP: Use topmost shape to crop others, then trim. Top shape becomes invisible.
            let cropResults = ProfessionalPathOperations.professionalCropWithShapeTracking(paths)
            
            // Adobe Illustrator Crop: Each resulting piece maintains the color of its original shape
            var shapeCounters: [Int: Int] = [:]
            
            for (croppedPath, originalShapeIndex, isInvisibleCropShape) in cropResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                if isInvisibleCropShape {
                    // Top shape becomes invisible (no fill, no stroke)
                    let invisibleCropShape = VectorShape(
                        name: "Crop Boundary (\(originalShape.name))",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil, // No stroke
                        fillStyle: nil,   // No fill - invisible
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(invisibleCropShape)
                    print("   ✅ Created invisible crop boundary from \(originalShape.name)")
                } else {
                    // Track how many pieces we've created from this original shape
                    shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                    let pieceNumber = shapeCounters[originalShapeIndex]!
                    
                    let croppedShape = VectorShape(
                        name: pieceNumber > 1 ? "Cropped \(originalShape.name) (\(pieceNumber))" : "Cropped \(originalShape.name)",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil, // CROP removes strokes (Adobe Illustrator standard)
                        fillStyle: originalShape.fillStyle,
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(croppedShape)
                }
            }
            
            print("✅ CROP: Created \(resultShapes.count) shapes (includes invisible crop boundary), removed strokes")
            
        case .dieline:
            // DIELINE: Apply Divide then convert all results to 1px black strokes with no fill
            let dielinePaths = ProfessionalPathOperations.dieline(paths)
            
            for (index, dielinePath) in dielinePaths.enumerated() {
                let dielineShape = VectorShape(
                    name: "Dieline \(index + 1)",
                    path: VectorPath(cgPath: dielinePath),
                    strokeStyle: StrokeStyle(
                        color: .black,
                        width: 1.0,
                        lineCap: CGLineCap.round,
                        lineJoin: CGLineJoin.round
                    ),
                    fillStyle: nil, // DIELINE has no fill - only 1px black stroke
                    transform: .identity,
                    opacity: 1.0
                )
                resultShapes.append(dielineShape)
            }
            print("✅ DIELINE: Created \(resultShapes.count) dieline shapes")
            
        case .minusBack:
            // MINUS BACK: Back objects subtract from front object, result takes color of FRONT object
            guard selectedShapes.count >= 2 else {
                print("❌ MINUS BACK requires at least 2 shapes")
                return
            }
            
            let frontShape = selectedShapes.last!     // Last in array = topmost = front
            let backShapes = Array(selectedShapes.dropLast()) // All others = back
            
            print("🔪 MINUS BACK: Front shape '\(frontShape.name)' - Back shapes: \(backShapes.map { $0.name })")
            
            var resultPath = frontShape.path.cgPath
            
            // Subtract each back shape from the result
            for backShape in backShapes {
                if let subtractedPath = ProfessionalPathOperations.minusBack(resultPath, from: backShape.path.cgPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(backShape.name)' from result")
                }
            }
            
            // Result takes style of FRONT object (Adobe Illustrator standard)
            let resultShape = VectorShape(
                name: "Minus Back Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: frontShape.strokeStyle,
                fillStyle: frontShape.fillStyle,
                transform: .identity,
                opacity: frontShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ MINUS BACK: Result takes front object's color (\(frontShape.name))")
        }
        
        guard !resultShapes.isEmpty else {
            print("❌ Pathfinder operation \(operation.rawValue) produced no results")
            return
        }
        
        // Remove original selected shapes
        document.removeSelectedShapes()
        
        // Add new result shapes and select them
        for resultShape in resultShapes {
            document.addShape(resultShape)
            document.selectShape(resultShape.id)
        }
        
        print("✅ PROFESSIONAL ADOBE ILLUSTRATOR pathfinder operation \(operation.rawValue) completed - created \(resultShapes.count) result shape(s)")
    }
    
    /// Determine which original shape a divided piece belongs to (for color assignment)
    private func determineOriginalShapeForDividedPiece(_ piece: CGPath, from originalShapes: [VectorShape]) -> VectorShape {
        // Get the center point of the piece
        let pieceBounds = piece.boundingBoxOfPath
        let pieceCenter = CGPoint(x: pieceBounds.midX, y: pieceBounds.midY)
        
        // Find which original shape contains this center point
        for shape in originalShapes {
            if shape.path.cgPath.contains(pieceCenter) {
                return shape
            }
        }
        
        // Fallback: use the first shape
        return originalShapes.first!
    }
}

struct PathfinderOperationButton: View {
    let operation: PathfinderOperation
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: operation.iconName)
                    .font(.system(size: operation.isShapeMode ? 14 : 12))
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                
                Text(operation.rawValue)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isEnabled ? .primary : .secondary)
            }
            .frame(height: operation.isShapeMode ? 48 : 42)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEnabled ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isEnabled ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle()) // Extend hit area to match entire button background
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .help(operation.description)
    }
}

// Legacy PathOperationButton for backward compatibility
struct PathOperationButton: View {
    let operation: PathOperation
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: operation.iconName)
                    .font(.system(size: 16))
                
                Text(operation.rawValue)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(isEnabled ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .help(operation.rawValue)
    }
}

// MARK: - Professional Offset Path Section (Adobe Illustrator Standards)

struct ProfessionalOffsetPathSection: View {
    @ObservedObject var document: VectorDocument
    @State private var offsetDistance: Double = 10.0
    @State private var selectedJoinType: JoinType = .round
    @State private var miterLimit: Double = 4.0
    @State private var showAdvanced: Bool = true
    @State private var keepOriginalPath: Bool = true
    @State private var cleanupOverlaps: Bool = false

    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with disclosure triangle
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Offset Path")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Adobe Illustrator icon
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            if showAdvanced {
                VStack(alignment: .leading, spacing: 10) {
                    // Offset Distance Control
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Offset:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(offsetDistance, specifier: "%.1f") pt")
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: $offsetDistance, in: -50...50, step: 0.5) {
                            Text("Offset Distance")
                        }
                        .controlSize(.small)
                        .tint(.blue)
                    }
                    
                    // Keep Original Path Checkbox (Adobe Illustrator Standard)
                    HStack {
                        Button {
                            keepOriginalPath.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: keepOriginalPath ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 14))
                                    .foregroundColor(keepOriginalPath ? .blue : .secondary)
                                
                                Text("Keep Original Path")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Keep the original path when creating offset (Adobe Illustrator default)")
                        
                        Spacer()
                    }
                    
                    // TrimX Checkbox (Professional cleanup for complex shapes)
                    HStack {
                        Button {
                            cleanupOverlaps.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cleanupOverlaps ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 14))
                                    .foregroundColor(cleanupOverlaps ? .blue : .secondary)
                                
                                Text("TrimX")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Clean up offset results using Trim operation between original and result")
                        
                        Spacer()
                    }
                    
                    // Join Type Selection (Adobe Illustrator style)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Joins:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            ForEach([JoinType.round, .square, .bevel, .miter], id: \.self) { joinType in
                                Button {
                                    selectedJoinType = joinType
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: joinType.iconName)
                                            .font(.system(size: 12))
                                        
                                        Text(joinType.displayName)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(selectedJoinType == joinType ? .accentColor : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedJoinType == joinType ? Color.accentColor.opacity(0.1) : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(selectedJoinType == joinType ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                            )
                                    )
                                    .contentShape(Rectangle()) // Extend hit area to match entire button background
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help(joinType.description)
                            }
                        }
                    }
                    
                    // Miter Limit (only show for miter joins)
                    if selectedJoinType == .miter {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Miter Limit:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(miterLimit, specifier: "%.1f")")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $miterLimit, in: 1.0...20.0, step: 0.1) {
                                Text("Miter Limit")
                            }
                            .controlSize(.small)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    

                    
                    // Action Buttons (Adobe Illustrator style)
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            // Offset Path button (handles both positive and negative offsets)
                            Button("Offset Path") {
                                performOffsetPath()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .help("Create offset path with current settings (⌘⌥O)")
                            .disabled(!canPerformOffset())
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 6) {
                            // Quick presets
                            Button("−10pt") {
                                offsetDistance = -10.0
                                performOffsetPath()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(!canPerformOffset())
                            
                            Button("+10pt") {
                                offsetDistance = 10.0
                                performOffsetPath()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(!canPerformOffset())
                            
                            Button("Reset") {
                                resetToDefaults()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func canPerformOffset() -> Bool {
        return !document.selectedShapeIDs.isEmpty
    }
    

    
    private func performOffsetPath() {
        guard !document.selectedShapeIDs.isEmpty else { return }
        
        print("🎨 PROFESSIONAL OFFSET PATH: \(offsetDistance)pt, join: \(selectedJoinType)")
        
        // Save to undo stack
        document.saveToUndoStack()
        
        // Get selected shapes
        let selectedShapes = document.getSelectedShapes()
        var newOffsetShapeIDs: Set<UUID> = []
        
        for shape in selectedShapes {
            // Use STROKE-BASED OFFSET for perfect smooth curves (no more Clipper polygons!)
            let effectiveMiterLimit = selectedJoinType == .square ? 1.0 : CGFloat(miterLimit)
            let strokeOptions = StrokeBasedOffsetOptions(
                offset: CGFloat(offsetDistance),
                joinType: mapJoinTypeToCoreGraphics(selectedJoinType),
                endType: .round,
                miterLimit: effectiveMiterLimit,
                keepOriginal: keepOriginalPath
            )
            
            // Create perfect smooth offset using Core Graphics strokes + expand
            var offsetPaths = shape.path.cgPath.strokeBasedOffset(strokeOptions)
            
            // Apply TrimX cleanup if requested (professional trim operation)
            if cleanupOverlaps && !offsetPaths.isEmpty {
                // TrimX Formula: Take result and original path, run "Trim", return the outside cleaned path
                for (index, offsetPath) in offsetPaths.enumerated() {
                    let pathsToTrim = [shape.path.cgPath, offsetPath]
                    let trimmedPaths = ProfessionalPathOperations.professionalTrim(pathsToTrim)
                    
                    // Find the outside path (usually the largest one after trim)
                    if let outsidePath = findOutsidePath(from: trimmedPaths, original: shape.path.cgPath, offset: offsetPath) {
                        offsetPaths[index] = outsidePath
                        print("🔧 TRIMX: Applied trim operation and selected outside cleaned path")
                    }
                }
            }
            
            // Convert results back to VectorShapes (now working with CGPaths directly!)
            for (index, offsetCGPath) in offsetPaths.enumerated() {
                let offsetVectorPath = VectorPath(cgPath: offsetCGPath)
                
                let offsetShape = VectorShape(
                    name: "\(shape.name) Offset \(offsetDistance > 0 ? "+" : "")\(offsetDistance)pt\(index > 0 ? " \(index + 1)" : "")",
                    path: offsetVectorPath,
                    strokeStyle: shape.strokeStyle,
                    fillStyle: shape.fillStyle,
                    transform: shape.transform,
                    opacity: shape.opacity
                )
                
                // Add to document (will be moved behind original later)
                document.addShape(offsetShape)
                newOffsetShapeIDs.insert(offsetShape.id)
            }
            
        }
        
        // Move offset shapes behind originals (Adobe Illustrator standard)
        if keepOriginalPath {
            // Send offset shapes to back so they appear behind the originals
            document.sendSelectedToBack()
        } else {
            // Remove original shapes if not keeping them
            document.removeSelectedShapes()
        }
        
        // Always select the result of the offset path operation
        document.selectedShapeIDs = newOffsetShapeIDs
        
        // Force document refresh so arrow tool can see newly created shapes
        document.objectWillChange.send()
         
         print("✅ OFFSET PATH: Created offset shapes \(keepOriginalPath ? "behind" : "replacing") originals")
    }
    

    
    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.2)) {
            offsetDistance = 10.0
            selectedJoinType = .miter
            miterLimit = 4.0
            keepOriginalPath = true
            cleanupOverlaps = false
        }
    }
    
    private func mapJoinTypeToCoreGraphics(_ joinType: JoinType) -> CGLineJoin {
        switch joinType {
        case .round: return .round
        case .miter: return .miter
        case .bevel: return .bevel
        case .square: return .miter  // Square corners with minimal miter limit
        }
    }
    
    /// Helper function to find the outside path from trim results
    private func findOutsidePath(from trimmedPaths: [CGPath], original: CGPath, offset: CGPath) -> CGPath? {
        guard !trimmedPaths.isEmpty else { return nil }
        
        // Get bounds of offset for comparison  
        let offsetBounds = offset.boundingBoxOfPath
        
        // The outside path is typically:
        // 1. The largest path by area
        // 2. The path that contains or is closest to the offset bounds
        var bestPath: CGPath?
        var bestScore: CGFloat = 0
        
        for path in trimmedPaths {
            let pathBounds = path.boundingBoxOfPath
            let pathArea = pathBounds.width * pathBounds.height
            
            // Score based on area and proximity to offset bounds
            let areaScore = pathArea
            let proximityScore = pathBounds.intersection(offsetBounds).width * pathBounds.intersection(offsetBounds).height
            let totalScore = areaScore + proximityScore * 2.0 // Weight proximity higher
            
            if totalScore > bestScore {
                bestScore = totalScore
                bestPath = path
            }
        }
        
        return bestPath ?? trimmedPaths.first
    }
}

// MARK: - JoinType Extensions for UI

extension JoinType {
    var iconName: String {
        switch self {
        case .miter: return "triangle"
        case .round: return "circle"
        case .bevel: return "hexagon"
        case .square: return "square"
        }
    }
    
    var displayName: String {
        switch self {
        case .miter: return "Miter"
        case .round: return "Round"
        case .bevel: return "Bevel"
        case .square: return "Square"
        }
    }
    
    var description: String {
        switch self {
        case .miter: return "Sharp pointed corners (Adobe Illustrator default)"
        case .round: return "Smooth rounded corners"
        case .bevel: return "Chamfered corners (cuts off sharp points)"
        case .square: return "Sharp square corners (no miter limit)"
        }
    }
}

// MARK: - CGPath to ClipperPath Conversion

extension CGPath {
    func toClipperPath() -> ClipperPath {
        // Use the professional curve-preserving conversion from ProfessionalBooleanGeometry
        // Use the professional curve-preserving conversion
        var points = ClipperPath()
        var currentPoint = CGPoint.zero
        
        self.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            
            switch element.type {
            case .moveToPoint:
                currentPoint = element.points[0]
                points.append(currentPoint)
                
            case .addLineToPoint:
                currentPoint = element.points[0]
                points.append(currentPoint)
                
            case .addQuadCurveToPoint:
                // High-quality quadratic curve approximation
                let control = element.points[0]
                let end = element.points[1]
                let start = currentPoint
                
                // Use adaptive subdivision for smooth curves
                let curvePoints = approximateQuadraticCurve(start: start, control: control, end: end, tolerance: 2.0)
                points.append(contentsOf: curvePoints)
                currentPoint = end
                
            case .addCurveToPoint:
                // High-quality cubic curve approximation
                let control1 = element.points[0]
                let control2 = element.points[1]
                let end = element.points[2]
                let start = currentPoint
                
                // Use adaptive subdivision for smooth curves
                let curvePoints = approximateCubicCurve(start: start, control1: control1, control2: control2, end: end, tolerance: 2.0)
                points.append(contentsOf: curvePoints)
                currentPoint = end
                
            case .closeSubpath:
                // Close the path - ClipperPath handles this automatically
                break
                
            @unknown default:
                break
            }
        }
        
        return points
    }
    
    private func approximateQuadraticCurve(start: CGPoint, control: CGPoint, end: CGPoint, tolerance: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        
        // Calculate the number of segments based on the curve's complexity
        let distance = distanceBetween(start, control) + distanceBetween(control, end)
        let segments = max(8, min(64, Int(distance / tolerance))) // Adaptive segment count
        
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let point = quadraticBezierPoint(t: t, start: start, control: control, end: end)
            points.append(point)
        }
        
        return points
    }
    
    private func approximateCubicCurve(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, tolerance: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        
        // Calculate the number of segments based on the curve's complexity
        let distance = distanceBetween(start, control1) + distanceBetween(control1, control2) + distanceBetween(control2, end)
        let segments = max(12, min(96, Int(distance / tolerance))) // Adaptive segment count for smoother curves
        
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let point = cubicBezierPoint(t: t, start: start, control1: control1, control2: control2, end: end)
            points.append(point)
        }
        
        return points
    }
    
    private func quadraticBezierPoint(t: CGFloat, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
        let x = (1-t)*(1-t)*start.x + 2*(1-t)*t*control.x + t*t*end.x
        let y = (1-t)*(1-t)*start.y + 2*(1-t)*t*control.y + t*t*end.y
        return CGPoint(x: x, y: y)
    }
    
    private func cubicBezierPoint(t: CGFloat, start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) -> CGPoint {
        let x = (1-t)*(1-t)*(1-t)*start.x + 3*(1-t)*(1-t)*t*control1.x + 3*(1-t)*t*t*control2.x + t*t*t*end.x
        let y = (1-t)*(1-t)*(1-t)*start.y + 3*(1-t)*(1-t)*t*control1.y + 3*(1-t)*t*t*control2.y + t*t*t*end.y
        return CGPoint(x: x, y: y)
    }
    
    private func distanceBetween(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
}

extension ClipperPath {
    func toCGPath() -> CGPath {
        let path = CGMutablePath()
        
        guard !self.isEmpty else { return path }
        
        path.move(to: self[0])
        for i in 1..<self.count {
            path.addLine(to: self[i])
        }
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Professional CMYK Input Section

struct CMYKInputSection: View {
    @ObservedObject var document: VectorDocument
    @State private var cyanValue: String = "0"
    @State private var magentaValue: String = "0"
    @State private var yellowValue: String = "0"
    @State private var blackValue: String = "0"
    @State private var previewColor: CMYKColor = CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CMYK Process Colors")
                    .font(.caption)
                .fontWeight(.medium)
                    .foregroundColor(.secondary)
            
            Text("Enter process color values (0-100%)")
                .font(.caption2)
                    .foregroundColor(.secondary)
            
            // CMYK Input Grid
            VStack(spacing: 6) {
                // Cyan and Magenta row
                HStack(spacing: 8) {
                    CMYKInputField(
                        label: "C",
                        value: $cyanValue,
                        color: .cyan,
                        onChange: updatePreview
                    )
                    
                    CMYKInputField(
                        label: "M",
                        value: $magentaValue,
                        color: .pink,
                        onChange: updatePreview
                    )
                }
                
                // Yellow and Black row
                HStack(spacing: 8) {
                    CMYKInputField(
                        label: "Y",
                        value: $yellowValue,
                        color: .yellow,
                        onChange: updatePreview
                    )
                    
                    CMYKInputField(
                        label: "K",
                        value: $blackValue,
                        color: .black,
                        onChange: updatePreview
                    )
                }
            }
            
            // Color Preview and Add Button
            HStack(spacing: 8) {
                // Preview
                Rectangle()
                    .fill(previewColor.color)
                    .frame(width: 40, height: 30)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .cornerRadius(4)
                
                VStack(alignment: .leading, spacing: 2) {
                                                    Text("CMYK(\(Int((previewColor.cyan * 100).isFinite ? previewColor.cyan * 100 : 0)), \(Int((previewColor.magenta * 100).isFinite ? previewColor.magenta * 100 : 0)), \(Int((previewColor.yellow * 100).isFinite ? previewColor.yellow * 100 : 0)), \(Int((previewColor.black * 100).isFinite ? previewColor.black * 100 : 0)))")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    
                    Button("Add to Swatches") {
                        addCMYKColorToSwatches()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    .controlSize(.small)
                }
                
                Spacer()
            }
            
            // Quick CMYK Presets
        VStack(alignment: .leading, spacing: 4) {
                Text("Common Process Colors")
                    .font(.caption2)
                .foregroundColor(.secondary)
            
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    CMYKPresetButton(name: "Cyan", cmyk: (100, 0, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Magenta", cmyk: (0, 100, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Yellow", cmyk: (0, 0, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Black", cmyk: (0, 0, 0, 100), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Red", cmyk: (0, 100, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Green", cmyk: (100, 0, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Blue", cmyk: (100, 100, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Rich Black", cmyk: (30, 30, 30, 100), action: applyCMYKPreset)
                }
            }
        }
        .onAppear {
            updatePreview()
        }
    }
    
    private func updatePreview() {
        let c = (Double(cyanValue) ?? 0) / 100.0
        let m = (Double(magentaValue) ?? 0) / 100.0
        let y = (Double(yellowValue) ?? 0) / 100.0
        let k = (Double(blackValue) ?? 0) / 100.0
        
        previewColor = CMYKColor(
            cyan: max(0, min(1, c)),
            magenta: max(0, min(1, m)),
            yellow: max(0, min(1, y)),
            black: max(0, min(1, k))
        )
    }
    
    private func addCMYKColorToSwatches() {
        let vectorColor = VectorColor.cmyk(previewColor)
        document.addColorSwatch(vectorColor)
    }
    
    private func applyCMYKPreset(_ cmyk: (Int, Int, Int, Int)) {
        cyanValue = String(cmyk.0)
        magentaValue = String(cmyk.1)
        yellowValue = String(cmyk.2)
        blackValue = String(cmyk.3)
        updatePreview()
    }
}

struct CMYKInputField: View {
    let label: String
    @Binding var value: String
    let color: Color
    let onChange: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
        HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            TextField("0", text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.caption)
                .frame(height: 24)
                .onChange(of: value) { oldValue, newValue in
                    // Validate and clamp input to 0-100
                    if let numValue = Double(newValue) {
                        if numValue < 0 {
                            value = "0"
                        } else if numValue > 100 {
                            value = "100"
                        }
                    }
                    onChange()
                }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CMYKPresetButton: View {
    let name: String
    let cmyk: (Int, Int, Int, Int)
    let action: ((Int, Int, Int, Int)) -> Void
    
    var body: some View {
        Button {
            action(cmyk)
        } label: {
            VStack(spacing: 2) {
                let cmykColor = CMYKColor(
                    cyan: Double(cmyk.0) / 100.0,
                    magenta: Double(cmyk.1) / 100.0,
                    yellow: Double(cmyk.2) / 100.0,
                    black: Double(cmyk.3) / 100.0
                )
                
                        Rectangle()
                    .fill(cmykColor.color)
                    .frame(height: 20)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: 0.5)
                    )
                    .cornerRadius(3)
                
                Text(name)
                    .font(.system(size: 8))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help("CMYK(\(cmyk.0), \(cmyk.1), \(cmyk.2), \(cmyk.3))")
    }
}

// MARK: - Professional Pantone Color Picker Sheet

struct PantoneColorPickerSheet: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchText = ""
    @State private var selectedCategory: PantoneCategory = .all
    @State private var selectedColor: PantoneColor?
    
    enum PantoneCategory: String, CaseIterable {
        case all = "All Colors"
        case classics = "Classic Colors"
        case metallics = "Metallics"
        case colorOfYear = "Color of the Year"
        
        func filter(_ colors: [PantoneColor]) -> [PantoneColor] {
            switch self {
            case .all:
                return colors
            case .classics:
                return colors.filter { color in
                    color.number.contains("C") && 
                    !color.name.localizedCaseInsensitiveContains("metallic") &&
                    !color.name.localizedCaseInsensitiveContains("peach fuzz")
                }
            case .metallics:
                return colors.filter { $0.number.contains("871") || $0.number.contains("877") }
            case .colorOfYear:
                return colors.filter { $0.name.localizedCaseInsensitiveContains("peach fuzz") }
            }
        }
    }
    
    private var allPantoneColors: [PantoneColor] {
        ColorManagement.loadPantoneColors()
    }
    
    private var filteredColors: [PantoneColor] {
        let categoryFiltered = selectedCategory.filter(allPantoneColors)
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { color in
                color.name.localizedCaseInsensitiveContains(searchText) ||
                color.number.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Search and Filter Section
                VStack(alignment: .leading, spacing: 12) {
                    // Search Bar
            HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search Pantone colors...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Category Filter
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PantoneCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                
                // Selected Color Preview
                if let selectedColor = selectedColor {
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(selectedColor.color)
                            .frame(height: 60)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PANTONE \(selectedColor.number)")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(selectedColor.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("RGB: \(Int(selectedColor.rgbEquivalent.red * 255)), \(Int(selectedColor.rgbEquivalent.green * 255)), \(Int(selectedColor.rgbEquivalent.blue * 255))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
            Spacer()
                            }
                            
                            HStack {
                                Text("CMYK: \(Int((selectedColor.cmykEquivalent.cyan * 100).isFinite ? selectedColor.cmykEquivalent.cyan * 100 : 0))%, \(Int((selectedColor.cmykEquivalent.magenta * 100).isFinite ? selectedColor.cmykEquivalent.magenta * 100 : 0))%, \(Int((selectedColor.cmykEquivalent.yellow * 100).isFinite ? selectedColor.cmykEquivalent.yellow * 100 : 0))%, \(Int((selectedColor.cmykEquivalent.black * 100).isFinite ? selectedColor.cmykEquivalent.black * 100 : 0))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // Color Grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(50), spacing: 8), count: 6), spacing: 8) {
                        ForEach(filteredColors, id: \.number) { color in
                            Button {
                                selectedColor = color
                            } label: {
            VStack(spacing: 4) {
                                    Rectangle()
                                        .fill(color.color)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Rectangle()
                                                .stroke(selectedColor?.number == color.number ? Color.blue : Color.gray, 
                                                       lineWidth: selectedColor?.number == color.number ? 2 : 1)
                                        )
                                    
                                    Text(color.number)
                                        .font(.system(size: 8))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
        }
        .buttonStyle(PlainButtonStyle())
                            .help("PANTONE \(color.number) - \(color.name)")
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Pantone Colors")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Swatches") {
                        if let selectedColor = selectedColor {
                            let vectorColor = VectorColor.pantone(selectedColor)
                            document.addColorSwatch(vectorColor)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(selectedColor == nil)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Select first color by default
            selectedColor = filteredColors.first
        }
        .onChange(of: selectedCategory) { oldValue, newValue in
            selectedColor = filteredColors.first
        }
        .onChange(of: searchText) { oldValue, newValue in
            selectedColor = filteredColors.first
        }
    }
}

// MARK: - Professional Color Picker Modal

struct ColorPickerModal: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    let title: String
    let onColorSelected: (VectorColor) -> Void
    
    var body: some View {
        NavigationView {
            ColorPanel(document: document, onColorSelected: onColorSelected)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
        .frame(width: 300, height: 500)
    }
}

// Preview
struct RightPanel_Previews: PreviewProvider {
    static var previews: some View {
        RightPanel(document: VectorDocument())
            .frame(height: 600)
    }
}
