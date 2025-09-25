//
//  TransformationControls.swift
//  logos inkpen.io
//
//  Created by Claude on 2025-09-21.
//

import SwiftUI
import Combine

// MARK: - Transform Origin Point
enum TransformOrigin: String, CaseIterable {
    case topLeft = "Top Left"
    case topCenter = "Top Center"
    case topRight = "Top Right"
    case middleLeft = "Middle Left"
    case center = "Center"
    case middleRight = "Middle Right"
    case bottomLeft = "Bottom Left"
    case bottomCenter = "Bottom Center"
    case bottomRight = "Bottom Right"

    var point: CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: 0, y: 0)
        case .topCenter: return CGPoint(x: 0.5, y: 0)
        case .topRight: return CGPoint(x: 1, y: 0)
        case .middleLeft: return CGPoint(x: 0, y: 0.5)
        case .center: return CGPoint(x: 0.5, y: 0.5)
        case .middleRight: return CGPoint(x: 1, y: 0.5)
        case .bottomLeft: return CGPoint(x: 0, y: 1)
        case .bottomCenter: return CGPoint(x: 0.5, y: 1)
        case .bottomRight: return CGPoint(x: 1, y: 1)
        }
    }
}

// MARK: - 9-Point Origin Selector
struct NinePointOriginSelector: View {
    @Binding var selectedOrigin: TransformOrigin

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3) { row in
                HStack(spacing: 2) {
                    ForEach(0..<3) { col in
                        let origin = originForPosition(row: row, col: col)
                        ZStack {
                            Rectangle()
                                .fill(selectedOrigin == origin ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                                .frame(width: 10, height: 10)

                            Circle()
                                .fill(selectedOrigin == origin ? Color.red : Color.gray.opacity(0.5))
                                .frame(width: selectedOrigin == origin ? 6 : 4, height: selectedOrigin == origin ? 6 : 4)
                        }
                        .frame(width: 10, height: 10)
                        .contentShape(Rectangle()) // Make entire area clickable
                        .onTapGesture {
                            selectedOrigin = origin
                        }
                    }
                }
            }
        }
        .frame(width: 38, height: 38)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .help("Transform origin: \(selectedOrigin.rawValue)")
    }

    private func originForPosition(row: Int, col: Int) -> TransformOrigin {
        let index = row * 3 + col
        return TransformOrigin.allCases[index]
    }
}

// MARK: - Transformation Controls
struct TransformationControls: View {
    @ObservedObject var document: VectorDocument
    @State private var keepProportions: Bool = true
    @State private var xValue: String = ""
    @State private var yValue: String = ""
    @State private var widthValue: String = ""
    @State private var heightValue: String = ""
    @State private var aspectRatio: CGFloat = 1.0
    @State private var updateTrigger: Bool = false

    var hasSelection: Bool {
        !document.selectedObjectIDs.isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            // 9-point origin selector
            NinePointOriginSelector(selectedOrigin: $document.transformOrigin)
                .disabled(!hasSelection)
                .opacity(hasSelection ? 1.0 : 0.5)

            // X coordinate
            HStack(spacing: 2) {
                Text("X:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $xValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 60)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        applyTransformation()
                    }
            }

            // Y coordinate
            HStack(spacing: 2) {
                Text("Y:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $yValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 60)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        applyTransformation()
                    }
            }

            // Width
            HStack(spacing: 2) {
                Text("W:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $widthValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 60)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        if keepProportions {
                            updateHeightProportionally()
                        }
                        applyTransformation()
                    }
            }

            // Height
            HStack(spacing: 2) {
                Text("H:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $heightValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 60)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        if keepProportions {
                            updateWidthProportionally()
                        }
                        applyTransformation()
                    }
            }

            // Keep proportions toggle - Use lock icons for clarity
            Button(action: {
                keepProportions.toggle()
            }) {
                ZStack {
                    // Background rectangle that defines the clickable area
                    RoundedRectangle(cornerRadius: 4)
                        .fill(keepProportions ?
                            Color(.displayP3, red: 0.0, green: 0.478, blue: 1.0) : // Display P3 system blue
                            Color(.displayP3, red: 1.0, green: 0.584, blue: 0.0) // Display P3 orange matching toolbar
                        )
                        .frame(width: 35, height: 30)  // 25% larger

                    // Lock icon
                    Image(systemName: keepProportions ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 15, weight: .medium))  // 25% larger icon
                        .foregroundColor(.white)
                }
                .frame(width: 35, height: 30)  // 25% larger click area
            }
            .buttonStyle(BorderlessButtonStyle())
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(keepProportions ?
                        Color(.displayP3, red: 0.0, green: 0.478, blue: 1.0).opacity(0.8) : // Display P3 system blue
                        Color(.displayP3, red: 1.0, green: 0.584, blue: 0.0).opacity(0.8), // Display P3 orange
                        lineWidth: 1.5)
                    .allowsHitTesting(false) // Don't block clicks
            )
            .shadow(color: keepProportions ?
                Color(.displayP3, red: 0.0, green: 0.478, blue: 1.0).opacity(0.3) : // Display P3 system blue
                Color(.displayP3, red: 1.0, green: 0.584, blue: 0.0).opacity(0.3), // Display P3 orange
                radius: 2)
            .disabled(!hasSelection)
            .opacity(hasSelection ? 1.0 : 0.3)
            .help(keepProportions ? "⚠️ Proportions LOCKED - Width/Height ratio maintained" : "✓ Proportions UNLOCKED - Free resize")
        }
        .padding(.horizontal, 8)
        .onAppear {
            updateValuesFromSelection()
        }
        .onChange(of: document.selectedObjectIDs) { _, _ in
            updateValuesFromSelection()
        }
        .onChange(of: document.transformOrigin) { _, _ in
            updateValuesFromSelection()
        }
        .onChange(of: document.objectPositionUpdateTrigger) { _, _ in
            // Update X,Y coordinates when objects are moved/dragged
            updateValuesFromSelection()
        }
        .onChange(of: document.currentDragOffset) { _, _ in
            // Live update X,Y during dragging
            updateValuesFromSelection()
        }
        .onChange(of: document.scalePreviewDimensions) { _, _ in
            // Live update W,H during scaling with handles
            if document.isHandleScalingActive && document.scalePreviewDimensions != .zero {
                widthValue = String(format: "%.2f", document.scalePreviewDimensions.width)
                heightValue = String(format: "%.2f", document.scalePreviewDimensions.height)
            }
        }
    }

    private func updateValuesFromSelection() {
        guard let bounds = getSelectionBounds() else {
            xValue = ""
            yValue = ""
            widthValue = ""
            heightValue = ""
            aspectRatio = 1.0
            return
        }

        // X,Y should show the position of the selected origin point
        // Account for current drag offset to show live position during dragging
        let origin = document.transformOrigin.point
        let x = bounds.minX + bounds.width * origin.x + document.currentDragOffset.x
        let y = bounds.minY + bounds.height * origin.y + document.currentDragOffset.y

        xValue = String(format: "%.2f", x)
        yValue = String(format: "%.2f", y)
        widthValue = String(format: "%.2f", bounds.width)
        heightValue = String(format: "%.2f", bounds.height)
        aspectRatio = bounds.height > 0 ? bounds.width / bounds.height : 1.0
    }

    private func updateHeightProportionally() {
        guard let width = Double(widthValue), aspectRatio > 0 else { return }
        let newHeight = width / aspectRatio
        heightValue = String(format: "%.2f", newHeight)
    }

    private func updateWidthProportionally() {
        guard let height = Double(heightValue), aspectRatio > 0 else { return }
        let newWidth = height * aspectRatio
        widthValue = String(format: "%.2f", newWidth)
    }

    private func transformPoint(_ point: CGPoint, currentOrigin: CGPoint, newOrigin: CGPoint, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        // Translate to origin
        let dx = point.x - currentOrigin.x
        let dy = point.y - currentOrigin.y

        // Scale
        let scaledX = dx * scaleX
        let scaledY = dy * scaleY

        // Translate to new position
        return CGPoint(x: scaledX + newOrigin.x, y: scaledY + newOrigin.y)
    }

    private func getSelectionBounds() -> CGRect? {
        guard !document.selectedObjectIDs.isEmpty else { return nil }

        var combinedBounds: CGRect?

        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    // Use group bounds for groups, regular bounds for other shapes
                    let shapeBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                    combinedBounds = combinedBounds.map { $0.union(shapeBounds) } ?? shapeBounds
                }
            }
        }

        return combinedBounds
    }

    private func applyTransformation() {
        guard let currentBounds = getSelectionBounds(),
              let newX = Double(xValue),
              let newY = Double(yValue),
              let newWidth = Double(widthValue),
              let newHeight = Double(heightValue),
              newWidth > 0,
              newHeight > 0 else { return }

        document.saveToUndoStack()

        // Calculate the origin point based on selected origin
        let originOffset = document.transformOrigin.point
        let currentOriginX = currentBounds.minX + currentBounds.width * originOffset.x
        let currentOriginY = currentBounds.minY + currentBounds.height * originOffset.y

        // The X,Y values ARE the position of the selected origin point
        let newOriginX = newX
        let newOriginY = newY

        // Calculate scale
        let scaleX = newWidth / currentBounds.width
        let scaleY = newHeight / currentBounds.height

        // Apply transformation to each selected object
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }),
               case .shape(var shape) = unifiedObject.objectType {

                // Check if this is a group - handle grouped shapes specially
                if shape.isGroupContainer {
                    // Transform each grouped shape
                    var transformedGroupedShapes: [VectorShape] = []
                    for var groupedShape in shape.groupedShapes {
                        var transformedElements: [PathElement] = []
                        for element in groupedShape.path.elements {
                            switch element {
                            case .move(let to):
                                let pt = CGPoint(x: to.x, y: to.y)
                                let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                          newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                          scaleX: scaleX, scaleY: scaleY)
                                transformedElements.append(.move(to: VectorPoint(newPt)))
                            case .line(let to):
                                let pt = CGPoint(x: to.x, y: to.y)
                                let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                          newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                          scaleX: scaleX, scaleY: scaleY)
                                transformedElements.append(.line(to: VectorPoint(newPt)))
                            case .curve(let to, let c1, let c2):
                                let toPt = transformPoint(CGPoint(x: to.x, y: to.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                         newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                         scaleX: scaleX, scaleY: scaleY)
                                let c1Pt = transformPoint(CGPoint(x: c1.x, y: c1.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                          newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                          scaleX: scaleX, scaleY: scaleY)
                                let c2Pt = transformPoint(CGPoint(x: c2.x, y: c2.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                          newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                          scaleX: scaleX, scaleY: scaleY)
                                transformedElements.append(.curve(to: VectorPoint(toPt), control1: VectorPoint(c1Pt), control2: VectorPoint(c2Pt)))
                            case .quadCurve(let to, let c):
                                let toPt = transformPoint(CGPoint(x: to.x, y: to.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                         newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                         scaleX: scaleX, scaleY: scaleY)
                                let cPt = transformPoint(CGPoint(x: c.x, y: c.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                        newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                        scaleX: scaleX, scaleY: scaleY)
                                transformedElements.append(.quadCurve(to: VectorPoint(toPt), control: VectorPoint(cPt)))
                            case .close:
                                transformedElements.append(.close)
                            }
                        }
                        groupedShape.path = VectorPath(elements: transformedElements, isClosed: groupedShape.path.isClosed)
                        groupedShape.updateBounds()
                        transformedGroupedShapes.append(groupedShape)
                    }
                    shape.groupedShapes = transformedGroupedShapes
                    shape.transform = .identity
                    shape.updateBounds()
                } else {
                    // Apply transform directly to path coordinates for regular shapes
                    var transformedElements: [PathElement] = []
                    for element in shape.path.elements {
                        switch element {
                        case .move(let to):
                            let pt = CGPoint(x: to.x, y: to.y)
                            let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                      newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                      scaleX: scaleX, scaleY: scaleY)
                            transformedElements.append(.move(to: VectorPoint(newPt)))
                        case .line(let to):
                            let pt = CGPoint(x: to.x, y: to.y)
                            let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                      newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                      scaleX: scaleX, scaleY: scaleY)
                            transformedElements.append(.line(to: VectorPoint(newPt)))
                        case .curve(let to, let c1, let c2):
                            let toPt = transformPoint(CGPoint(x: to.x, y: to.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                     newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                     scaleX: scaleX, scaleY: scaleY)
                            let c1Pt = transformPoint(CGPoint(x: c1.x, y: c1.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                      newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                      scaleX: scaleX, scaleY: scaleY)
                            let c2Pt = transformPoint(CGPoint(x: c2.x, y: c2.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                      newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                      scaleX: scaleX, scaleY: scaleY)
                            transformedElements.append(.curve(to: VectorPoint(toPt), control1: VectorPoint(c1Pt), control2: VectorPoint(c2Pt)))
                        case .quadCurve(let to, let c):
                            let toPt = transformPoint(CGPoint(x: to.x, y: to.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                     newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                     scaleX: scaleX, scaleY: scaleY)
                            let cPt = transformPoint(CGPoint(x: c.x, y: c.y), currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                    newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                    scaleX: scaleX, scaleY: scaleY)
                            transformedElements.append(.quadCurve(to: VectorPoint(toPt), control: VectorPoint(cPt)))
                        case .close:
                            transformedElements.append(.close)
                        }
                    }
                    shape.path = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
                    shape.transform = .identity // Clear transform since we applied it to coordinates
                    shape.updateBounds()
                }

                // Update the shape
                let layerIndex = unifiedObject.layerIndex
                if layerIndex < document.layers.count {
                    let shapes = document.getShapesForLayer(layerIndex)
                    if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {
                        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
                    }
                }
            }
        }

        // Refresh unified objects and UI
        document.populateUnifiedObjectsFromLayersPreservingOrder()
        document.objectWillChange.send()

        // Update displayed values
        updateValuesFromSelection()
    }
}
