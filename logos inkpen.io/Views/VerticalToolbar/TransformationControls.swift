import SwiftUI
import Combine

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
                        .contentShape(Rectangle())
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

struct TransformationControls: View {
    @ObservedObject var document: VectorDocument
    @State private var keepProportions: Bool = false
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
            NinePointOriginSelector(selectedOrigin: $document.transformOrigin)
                .disabled(!hasSelection)
                .opacity(hasSelection ? 1.0 : 0.5)

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
                    .onChange(of: widthValue) { _, _ in
                        if keepProportions && !widthValue.isEmpty {
                            updateHeightProportionally()
                        }
                    }
            }

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
                    .onChange(of: heightValue) { _, _ in
                        if keepProportions && !heightValue.isEmpty {
                            updateWidthProportionally()
                        }
                    }
            }

            Button(action: {
                keepProportions.toggle()
            }) {
                Image(systemName: keepProportions ? "lock.fill" : "lock.open.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundColor(keepProportions ? .orange : Color(NSColor.systemBlue))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(keepProportions ? Color.orange.opacity(0.4) : Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .overlay(
                keepProportions ?
                AnyView(
                    VStack(spacing: 0) {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 24, y: 0))
                        }
                        .stroke(Color.orange, lineWidth: 2)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 24, y: 0))
                        }
                        .stroke(Color.orange, lineWidth: 2)
                    }
                    .frame(width: 24, height: 24)
                    .opacity(0)
                    .allowsHitTesting(false)
                ) :
                AnyView(
                    EmptyView()
                        .frame(width: 24, height: 24)
                        .allowsHitTesting(false)
            )
            )
            .shadow(color: keepProportions ?
                Color(.displayP3, red: 0.0, green: 0.478, blue: 1.0).opacity(0.3) :
                Color(.displayP3, red: 1.0, green: 0.584, blue: 0.0).opacity(0.3),
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
            if !document.isHandleScalingActive {
                updateValuesFromSelection()
            }
        }
        .onChange(of: document.currentDragOffset) { _, newOffset in
            if newOffset != .zero {
                updatePositionOnly()
            } else {
                updateValuesFromSelection()
            }
        }
        .onChange(of: document.scalePreviewDimensions) { _, _ in
            if document.isHandleScalingActive && document.scalePreviewDimensions != .zero {
                widthValue = String(format: "%.2f", document.scalePreviewDimensions.width)
                heightValue = String(format: "%.2f", document.scalePreviewDimensions.height)
            }
        }
    }

    private func updatePositionOnly() {
        let bounds = document.cachedSelectionBounds ?? getSelectionBounds()

        guard let bounds = bounds else {
            xValue = ""
            yValue = ""
            return
        }

        let origin = document.transformOrigin.point
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let x = bounds.minX + bounds.width * origin.x + document.currentDragOffset.x - pageOrigin.x
        let y = bounds.minY + bounds.height * origin.y + document.currentDragOffset.y - pageOrigin.y

        xValue = String(format: "%.2f", x)
        yValue = String(format: "%.2f", y)
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

        let origin = document.transformOrigin.point
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let x = bounds.minX + bounds.width * origin.x + document.currentDragOffset.x - pageOrigin.x
        let y = bounds.minY + bounds.height * origin.y + document.currentDragOffset.y - pageOrigin.y

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
        let dx = point.x - currentOrigin.x
        let dy = point.y - currentOrigin.y
        let scaledX = dx * scaleX
        let scaledY = dy * scaleY

        return CGPoint(x: scaledX + newOrigin.x, y: scaledY + newOrigin.y)
    }

    private func getSelectionBounds() -> CGRect? {
        guard !document.selectedObjectIDs.isEmpty else { return nil }

        var combinedBounds: CGRect?

        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .text(let shape):
                    let position = shape.textPosition ?? CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                    let shapeBounds = CGRect(
                        x: position.x,
                        y: position.y,
                        width: shape.bounds.width,
                        height: shape.bounds.height
                    )
                    combinedBounds = combinedBounds.map { $0.union(shapeBounds) } ?? shapeBounds
                case .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
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

        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for objectID in document.selectedObjectIDs {
            if let shape = document.findShape(by: objectID) {
                oldShapes[objectID] = shape
                objectIDs.append(objectID)
            }
        }

        let originOffset = document.transformOrigin.point
        let currentOriginX = currentBounds.minX + currentBounds.width * originOffset.x
        let currentOriginY = currentBounds.minY + currentBounds.height * originOffset.y
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let newOriginX = newX + pageOrigin.x
        let newOriginY = newY + pageOrigin.y
        let scaleX = newWidth / currentBounds.width
        let scaleY = newHeight / currentBounds.height

        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID),
               case .shape(var shape) = unifiedObject.objectType {

                if shape.isGroupContainer {
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
                            case .curve(let to, let control1, let control2):
                                let toPt = CGPoint(x: to.x, y: to.y)
                                let c1Pt = CGPoint(x: control1.x, y: control1.y)
                                let c2Pt = CGPoint(x: control2.x, y: control2.y)
                                let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                          newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                          scaleX: scaleX, scaleY: scaleY)
                                let newC1 = transformPoint(c1Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                          newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                          scaleX: scaleX, scaleY: scaleY)
                                let newC2 = transformPoint(c2Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                          newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                          scaleX: scaleX, scaleY: scaleY)
                                transformedElements.append(.curve(to: VectorPoint(newTo),
                                                                 control1: VectorPoint(newC1),
                                                                 control2: VectorPoint(newC2)))
                            case .quadCurve(let to, let control):
                                let toPt = CGPoint(x: to.x, y: to.y)
                                let cPt = CGPoint(x: control.x, y: control.y)
                                let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                          newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                          scaleX: scaleX, scaleY: scaleY)
                                let newC = transformPoint(cPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                        newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                        scaleX: scaleX, scaleY: scaleY)
                                transformedElements.append(.quadCurve(to: VectorPoint(newTo),
                                                                     control: VectorPoint(newC)))
                            case .close:
                                transformedElements.append(.close)
                            }
                        }
                        groupedShape.path = VectorPath(elements: transformedElements)
                        groupedShape.updateBounds()
                        transformedGroupedShapes.append(groupedShape)
                    }
                    shape.groupedShapes = transformedGroupedShapes
                    shape.updateBounds()
                } else if shape.isTextObject {
                    let currentPosition = shape.textPosition ?? CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                    let newPosition = transformPoint(currentPosition,
                                                    currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                    newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                    scaleX: scaleX, scaleY: scaleY)

                    shape.textPosition = newPosition
                    shape.transform = CGAffineTransform(translationX: newPosition.x, y: newPosition.y)

                    if scaleX != 1.0 || scaleY != 1.0 {
                        let newWidth = shape.bounds.width * scaleX
                        let newHeight = shape.bounds.height * scaleY
                        shape.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)

                        if let areaSize = shape.areaSize {
                            shape.areaSize = CGSize(width: areaSize.width * scaleX, height: areaSize.height * scaleY)
                        }
                    }
                } else {
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
                        case .curve(let to, let control1, let control2):
                            let toPt = CGPoint(x: to.x, y: to.y)
                            let c1Pt = CGPoint(x: control1.x, y: control1.y)
                            let c2Pt = CGPoint(x: control2.x, y: control2.y)
                            let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                      newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                      scaleX: scaleX, scaleY: scaleY)
                            let newC1 = transformPoint(c1Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                      newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                      scaleX: scaleX, scaleY: scaleY)
                            let newC2 = transformPoint(c2Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                      newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                      scaleX: scaleX, scaleY: scaleY)
                            transformedElements.append(.curve(to: VectorPoint(newTo),
                                                             control1: VectorPoint(newC1),
                                                             control2: VectorPoint(newC2)))
                        case .quadCurve(let to, let control):
                            let toPt = CGPoint(x: to.x, y: to.y)
                            let cPt = CGPoint(x: control.x, y: control.y)
                            let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                      newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                      scaleX: scaleX, scaleY: scaleY)
                            let newC = transformPoint(cPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                    newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                    scaleX: scaleX, scaleY: scaleY)
                            transformedElements.append(.quadCurve(to: VectorPoint(newTo),
                                                                 control: VectorPoint(newC)))
                        case .close:
                            transformedElements.append(.close)
                        }
                    }
                    shape.path = VectorPath(elements: transformedElements)
                    shape.updateBounds()
                }

                for layerIndex in document.layers.indices {
                    let shapes = document.getShapesForLayer(layerIndex)
                    if let shapeIndex = shapes.firstIndex(where: { $0.id == objectID }) {
                        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)

                        if shape.isTextObject {
                            if let position = shape.textPosition {
                                document.updateTextPositionInUnified(id: shape.id, position: position)
                            }
                            if let areaSize = shape.areaSize {
                                document.updateTextAreaSizeInUnified(id: shape.id, areaSize: areaSize)
                            }
                            document.updateTextBoundsInUnified(id: shape.id, bounds: shape.bounds)
                        }
                        break
                    }
                }
            }
        }

        var newShapes: [UUID: VectorShape] = [:]
        for objectID in objectIDs {
            if let updatedShape = document.findShape(by: objectID) {
                newShapes[objectID] = updatedShape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }

        updateValuesFromSelection()
    }
}
