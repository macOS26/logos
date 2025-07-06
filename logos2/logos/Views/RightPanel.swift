//
//  RightPanel.swift
//  logos
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
    }
}

enum PanelTab: String, CaseIterable {
    case layers = "Layers"
    case properties = "Stroke/Fill"
    case color = "Color"
    case pathOps = "Path Ops"
    
    var iconName: String {
        switch self {
        case .layers: return "square.stack"
        case .properties: return "paintbrush"
        case .color: return "paintpalette"
        case .pathOps: return "square.grid.2x2"
        }
    }
}

struct PanelTabBar: View {
    @Binding var selectedTab: PanelTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .bottom
        )
    }
}

struct LayersPanel: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Layers")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    document.addLayer()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add Layer")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Layers List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(document.layers.indices.reversed(), id: \.self) { index in
                        LayerRow(
                            layer: document.layers[index],
                            isSelected: document.selectedLayerIndex == index,
                            onSelect: {
                                document.selectedLayerIndex = index
                            },
                            onToggleVisibility: {
                                document.layers[index].isVisible.toggle()
                            },
                            onToggleLock: {
                                document.layers[index].isLocked.toggle()
                            },
                            onDelete: {
                                document.removeLayer(at: index)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            
            Spacer()
        }
    }
}

struct LayerRow: View {
    let layer: VectorLayer
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onToggleLock: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Visibility Toggle
            Button {
                onToggleVisibility()
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 12))
                    .foregroundColor(layer.isVisible ? .primary : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle Visibility")
            
            // Lock Toggle
            Button {
                onToggleLock()
            } label: {
                Image(systemName: layer.isLocked ? "lock" : "lock.open")
                    .font(.system(size: 12))
                    .foregroundColor(layer.isLocked ? .primary : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle Lock")
            
            // Layer Name
            Text(layer.name)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Shape Count
            Text("\(layer.shapes.count)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            
            // Delete Button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Delete Layer")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .onTapGesture {
            onSelect()
        }
    }
}

// PropertiesPanel removed - using StrokeFillPanel instead

// Old property structures removed - using StrokeFillPanel instead

struct ColorPanel: View {
    @ObservedObject var document: VectorDocument
    
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
                    set: { document.settings.colorMode = $0 }
                )) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
            }
            .padding(.horizontal, 12)
            
            // Color Swatches
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 4), count: 8), spacing: 4) {
                    ForEach(Array(document.colorSwatches.enumerated()), id: \.offset) { index, color in
                        Rectangle()
                            .fill(color.color)
                            .frame(width: 30, height: 30)
                            .border(Color.gray, width: 1)
                            .onTapGesture {
                                // Select color
                            }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
        }
    }
}

struct PathOperationsPanel: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Path Operations")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Path Operations
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(PathOperation.allCases, id: \.self) { operation in
                    PathOperationButton(
                        operation: operation,
                        isEnabled: document.selectedShapeIDs.count >= 2
                    ) {
                        // Perform path operation
                        performPathOperation(operation)
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
    }
    
    private func performPathOperation(_ operation: PathOperation) {
        // Implementation would go here
        print("Performing path operation: \(operation.rawValue)")
    }
}

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

// Preview
struct RightPanel_Previews: PreviewProvider {
    static var previews: some View {
        RightPanel(document: VectorDocument())
            .frame(height: 600)
    }
}