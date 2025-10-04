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
    @State private var pressureCurve: [CGPoint] = PreferencesView.defaultPressureCurve()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pressure Sensitivity Section
            GroupBox(label: Label("Pressure Sensitivity", systemImage: "hand.draw").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {

                    // Pressure curve editor
                    PressureCurveEditor(curve: $pressureCurve, size: 300)
                        .padding(.vertical, 8)

                    // Preset buttons
                    HStack(spacing: 8) {
                        Button("Linear") {
                            pressureCurve = PreferencesView.defaultPressureCurve()
                        }
                        .buttonStyle(.bordered)

                        Button("Soft") {
                            pressureCurve = [
                                CGPoint(x: 0.0, y: 0.0),
                                CGPoint(x: 0.25, y: 0.4),
                                CGPoint(x: 0.5, y: 0.65),
                                CGPoint(x: 0.75, y: 0.85),
                                CGPoint(x: 1.0, y: 1.0)
                            ]
                        }
                        .buttonStyle(.bordered)

                        Button("Hard") {
                            pressureCurve = [
                                CGPoint(x: 0.0, y: 0.0),
                                CGPoint(x: 0.25, y: 0.1),
                                CGPoint(x: 0.5, y: 0.35),
                                CGPoint(x: 0.75, y: 0.6),
                                CGPoint(x: 1.0, y: 1.0)
                            ]
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 550)
        .onAppear {
            loadPressureCurve()
        }
        .onChange(of: pressureCurve) { oldValue, newValue in
            savePressureCurve()
        }
    }

    private func loadPressureCurve() {
        // Load from UserDefaults using the SAME key as AppState
        if let data = UserDefaults.standard.array(forKey: "pressureCurve") as? [[String: Double]] {
            let loadedCurve = data.compactMap { dict -> CGPoint? in
                guard let x = dict["x"], let y = dict["y"] else { return nil }
                return CGPoint(x: x, y: y)
            }
            if loadedCurve.count >= 2 {
                pressureCurve = loadedCurve
            }
        }
    }

    private func savePressureCurve() {
        // Save to UserDefaults using the SAME key as AppState
        let data = pressureCurve.map { ["x": $0.x, "y": $0.y] }
        UserDefaults.standard.set(data, forKey: "pressureCurve")
        UserDefaults.standard.synchronize()

        // ALSO update AppState directly so tools get the change immediately
        appState.pressureCurve = pressureCurve

    }

    // Helper functions
    static func defaultPressureCurve() -> [CGPoint] {
        return [
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: 0.25, y: 0.25),
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.75, y: 0.75),
            CGPoint(x: 1.0, y: 1.0)
        ]
    }

    static func defaultPressureCurveData() -> Data {
        let defaultCurve = defaultPressureCurve()
        return (try? JSONEncoder().encode(defaultCurve)) ?? Data()
    }
}
