//
//  ObjectRow.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// PROFESSIONAL OBJECT ROW (Individual objects within layers)
struct ObjectRow: View {
    enum ObjectType: String {
        case shape = "shape"
        case text = "text"
    }
    
    let objectType: ObjectType
    let objectId: UUID
    let name: String
    let isSelected: Bool
    let isVisible: Bool
    let isLocked: Bool
    let onSelect: (_ isShiftPressed: Bool, _ isCommandPressed: Bool) -> Void
    let layerIndex: Int
    let document: VectorDocument
    
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Object Type Icon
            Image(systemName: objectIcon)
                    .font(.system(size: 10))
                .foregroundColor(objectIconColor)
                .frame(width: 12)
            
            // Selection Indicator
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                .frame(width: 8, height: 8)
            
            // Object Name
            Text(name)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .blue : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Visibility/Lock Indicators
            HStack(spacing: 2) {
                if !isVisible {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                if isLocked {
                    Image(systemName: "lock")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .opacity(isDragging ? 0.5 : 1.0)
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .contentShape(Rectangle())
        .onTapGesture {
            let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
            let isCommandPressed = NSEvent.modifierFlags.contains(.command)
            onSelect(isShiftPressed, isCommandPressed)
        }
        .draggable(DraggableVectorObject(
            objectType: objectType == .text ? .text : .shape,
            objectId: objectId,
            sourceLayerIndex: layerIndex
        )) {
            // Custom drag preview
            HStack(spacing: 4) {
                Image(systemName: objectIcon)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.8))
            .cornerRadius(6)
        }
        .onChange(of: isDragging) { oldValue, newValue in
            // Visual feedback during drag
            //if newValue {
                //Log.fileOperation("🎯 Dragging \(objectType.rawValue): \(name)", level: .info)
            //}
        }
        .contextMenu {
            // Context menu for object operations
            Button("Select") {
                onSelect(false, false)
            }
            
            Divider()
            
            if objectType == .shape {
                Button("Duplicate Shape") {
                    // Future implementation
                }
                Button("Delete Shape") {
                    document.selectedShapeIDs = [objectId]
                    document.removeSelectedShapes()
                }
            } else {
                Button("Duplicate Text") {
                    // Future implementation
                }
                Button("Delete Text") {
                    document.selectedTextIDs = [objectId]
                    document.removeSelectedText()
                }
            }
            
            Divider()
            
            Button(isVisible ? "Hide" : "Show") {
                // Toggle visibility - future implementation
            }
            
            Button(isLocked ? "Unlock" : "Lock") {
                // Toggle lock - future implementation
            }
        }
    }
    
    private var objectIcon: String {
        switch objectType {
        case .shape: return "square"
        case .text: return "textformat"
        }
    }
    
    private var objectIconColor: Color {
        switch objectType {
        case .shape: return .blue
        case .text: return .green
        }
    }
} 

// MARK: - Preferences View
struct PreferencesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\._openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.title2)
                .fontWeight(.semibold)
            
            GroupBox(label: Label("PDF Export", systemImage: "doc.richtext").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gradient Rendering Method")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Picker("", selection: Binding(get: { appState.pdfGradientMethod }, set: { appState.pdfGradientMethod = $0 })) {
                            ForEach(AppState.PDFGradientMethod.allCases, id: \.self) { method in
                                Text(method.displayName).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        // Show blend steps field when blend mode is selected
                        if appState.pdfGradientMethod == .blend {
                            HStack {
                                Text("Blend Steps:")
                                    .font(.system(size: 12))
                                TextField("", value: Binding(
                                    get: { appState.pdfBlendSteps },
                                    set: { appState.pdfBlendSteps = $0 }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                Text("(10-255)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Show mesh grid fields when mesh mode is selected
                        if appState.pdfGradientMethod == .mesh {
                            HStack {
                                Text("Grid Size:")
                                    .font(.system(size: 12))
                                TextField("", value: Binding(
                                    get: { appState.pdfMeshGridX },
                                    set: { appState.pdfMeshGridX = $0 }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                Text("×")
                                    .font(.system(size: 12))
                                TextField("", value: Binding(
                                    get: { appState.pdfMeshGridY },
                                    set: { appState.pdfMeshGridY = $0 }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                Text("(4-50)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text("Smooth: Standard. Baked: No transparency. Blend: Vector steps. Mesh: Grid patches.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                    }
                }
                .padding(.vertical, 8)
            }

            GroupBox(label: Label("Performance HUD", systemImage: "gauge.medium").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: Binding(get: { appState.enableSystemMetalHUD }, set: { appState.enableSystemMetalHUD = $0 })) {
                        Text("Show Apple Metal Performance HUD")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(.vertical, 8)
            }

            GroupBox(label: Label("Brush Preview", systemImage: "paintbrush").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview Style")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Picker("", selection: Binding(get: { appState.brushPreviewStyle }, set: { appState.brushPreviewStyle = $0 })) {
                            Text("Blue Outline").tag(AppState.BrushPreviewStyle.outline)
                            Text("Object Fill Color").tag(AppState.BrushPreviewStyle.fill)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    Toggle(isOn: Binding(get: { appState.brushPreviewIsFinal }, set: { appState.brushPreviewIsFinal = $0 })) {
                        Text("Preview is final (don't change on mouse up)")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 500)
    }
}