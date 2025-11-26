import SwiftUI

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
        .background(Color.platformControlBackground)
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
    let document: VectorDocument
    @Binding var liveDragOffset: CGPoint
    @Binding var liveScaleDimensions: CGSize
    @State private var keepProportions: Bool = false
    @State private var xValue: String = ""
    @State private var yValue: String = ""
    @State private var widthValue: String = ""
    @State private var heightValue: String = ""
    @State private var aspectRatio: CGFloat = 1.0

    private var transformOriginBinding: Binding<TransformOrigin> {
        Binding(
            get: { document.viewState.transformOrigin },
            set: { document.viewState.transformOrigin = $0 }
        )
    }

    var hasSelection: Bool {
        !document.viewState.PublishedSelectedObjectIDs.isEmpty
    }

    private var currentUnit: MeasurementUnit {
        document.settings.unit
    }

    private var unitSuffix: String {
        currentUnit.abbreviation
    }

    var body: some View {
        HStack(spacing: 10) {
            NinePointOriginSelector(selectedOrigin: transformOriginBinding)
                .disabled(!hasSelection)
                .opacity(hasSelection ? 1.0 : 0.5)

            HStack(spacing: 2) {
                Text("X:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $xValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 50)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        applyTransformation()
                    }
                Text(unitSuffix)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 16, alignment: .leading)
            }

            HStack(spacing: 2) {
                Text("Y:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $yValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 50)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        applyTransformation()
                    }
                Text(unitSuffix)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 16, alignment: .leading)
            }

            HStack(spacing: 2) {
                Text("W:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $widthValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 50)
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
                Text(unitSuffix)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 16, alignment: .leading)
            }

            HStack(spacing: 2) {
                Text("H:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $heightValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 50)
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
                Text(unitSuffix)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 16, alignment: .leading)
            }

            Button(action: {
                keepProportions.toggle()
            }) {
                Image(systemName: keepProportions ? "lock.fill" : "lock.open.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundColor(keepProportions ? .orange : Color(PlatformColor.systemBlue))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.platformControlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(keepProportions ? Color.orange.opacity(0.4) : Color.accentColor.opacity(0.2), lineWidth: 1)
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
        .onChange(of: document.viewState.selectedObjectIDs) { _, _ in
            updateValuesFromSelection()
        }
        .onChange(of: document.viewState.transformOrigin) { _, _ in
            updateValuesFromSelection()
        }
        .onChange(of: document.viewState.objectPositionUpdateTrigger) { _, _ in
            if !document.isHandleScalingActive {
                updateValuesFromSelection()
            }
        }
        .onChange(of: liveDragOffset) { _, _ in
            updatePositionOnly()
        }
        .onChange(of: liveScaleDimensions) { _, _ in
            if document.isHandleScalingActive && liveScaleDimensions != .zero {
                widthValue = currentUnit.format(currentUnit.fromPoints(liveScaleDimensions.width))
                heightValue = currentUnit.format(currentUnit.fromPoints(liveScaleDimensions.height))
            }
        }
        .onChange(of: document.settings.unit) { _, _ in
            updateValuesFromSelection()
        }
    }

    private func updatePositionOnly() {
        let bounds = document.cachedSelectionBounds ?? getSelectionBounds()

        guard let bounds = bounds else {
            xValue = ""
            yValue = ""
            return
        }

        let origin = document.viewState.transformOrigin.point
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let xInPoints = bounds.minX + bounds.width * origin.x + liveDragOffset.x - pageOrigin.x
        let yInPoints = bounds.minY + bounds.height * origin.y + liveDragOffset.y - pageOrigin.y

        xValue = currentUnit.format(currentUnit.fromPoints(xInPoints))
        yValue = currentUnit.format(currentUnit.fromPoints(yInPoints))
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

        let origin = document.viewState.transformOrigin.point
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let xInPoints = bounds.minX + bounds.width * origin.x - pageOrigin.x
        let yInPoints = bounds.minY + bounds.height * origin.y - pageOrigin.y

        xValue = currentUnit.format(currentUnit.fromPoints(xInPoints))
        yValue = currentUnit.format(currentUnit.fromPoints(yInPoints))
        widthValue = currentUnit.format(currentUnit.fromPoints(bounds.width))
        heightValue = currentUnit.format(currentUnit.fromPoints(bounds.height))
        aspectRatio = bounds.height > 0 ? bounds.width / bounds.height : 1.0
    }

    private func updateHeightProportionally() {
        guard let width = Double(widthValue), aspectRatio > 0 else { return }
        let newHeight = width / aspectRatio
        heightValue = currentUnit.format(newHeight)
    }

    private func updateWidthProportionally() {
        guard let height = Double(heightValue), aspectRatio > 0 else { return }
        let newWidth = height * aspectRatio
        widthValue = currentUnit.format(newWidth)
    }

    private func transformPoint(_ point: CGPoint, currentOrigin: CGPoint, newOrigin: CGPoint, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        let dx = point.x - currentOrigin.x
        let dy = point.y - currentOrigin.y
        let scaledX = dx * scaleX
        let scaledY = dy * scaleY

        return CGPoint(x: scaledX + newOrigin.x, y: scaledY + newOrigin.y)
    }

    private func getSelectionBounds() -> CGRect? {
        guard !document.viewState.selectedObjectIDs.isEmpty else { return nil }

        var combinedBounds: CGRect?

        for objectID in document.viewState.selectedObjectIDs {
            if let newVectorObject = document.snapshot.objects[objectID] {
                switch newVectorObject.objectType {
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
                     .image(let shape),
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
              let newXInUnit = Double(xValue),
              let newYInUnit = Double(yValue),
              let newWidthInUnit = Double(widthValue),
              let newHeightInUnit = Double(heightValue),
              newWidthInUnit > 0,
              newHeightInUnit > 0 else { return }

        // Convert user input from document units to points
        let newX = currentUnit.toPoints(newXInUnit)
        let newY = currentUnit.toPoints(newYInUnit)
        let newWidth = currentUnit.toPoints(newWidthInUnit)
        let newHeight = currentUnit.toPoints(newHeightInUnit)

        document.modifySelectedShapesWithUndo(
            preCapture: {
                let originOffset = document.viewState.transformOrigin.point
                let currentOriginX = currentBounds.minX + currentBounds.width * originOffset.x
                let currentOriginY = currentBounds.minY + currentBounds.height * originOffset.y
                let pageOrigin = document.settings.pageOrigin ?? .zero
                let newOriginX = newX + pageOrigin.x
                let newOriginY = newY + pageOrigin.y
                let scaleX = newWidth / currentBounds.width
                let scaleY = newHeight / currentBounds.height

                for objectID in document.viewState.selectedObjectIDs {
                    if let newVectorObject = document.snapshot.objects[objectID],
                       case .shape(var shape) = newVectorObject.objectType {

                        if shape.isGroupContainer {
                            var transformedGroupedShapes: [VectorShape] = []
                            for var groupedShape in shape.groupedShapes {
                                var transformedElements: [PathElement] = []
                                for element in groupedShape.path.elements {
                                    switch element {
                                    case .move(let to):
                                        let pt = to.cgPoint
                                        let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.move(to: VectorPoint(newPt)))
                                    case .line(let to):
                                        let pt = to.cgPoint
                                        let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.line(to: VectorPoint(newPt)))
                                    case .curve(let to, let control1, let control2):
                                        let toPt = to.cgPoint
                                        let c1Pt = control1.cgPoint
                                        let c2Pt = control2.cgPoint
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
                                        let toPt = to.cgPoint
                                        let cPt = control.cgPoint
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
                        } else if shape.typography != nil {
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
                                    let pt = to.cgPoint
                                    let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.move(to: VectorPoint(newPt)))
                                case .line(let to):
                                    let pt = to.cgPoint
                                    let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.line(to: VectorPoint(newPt)))
                                case .curve(let to, let control1, let control2):
                                    let toPt = to.cgPoint
                                    let c1Pt = control1.cgPoint
                                    let c2Pt = control2.cgPoint
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
                                    let toPt = to.cgPoint
                                    let cPt = control.cgPoint
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

                        for layerIndex in document.snapshot.layers.indices {
                            let shapes = document.getShapesForLayer(layerIndex)
                            if let shapeIndex = shapes.firstIndex(where: { $0.id == objectID }) {
                                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)

                                if shape.typography != nil {
                                    if let position = shape.textPosition {
                                        document.updateTextPositionInUnified(id: shape.id, position: position)
                                    }
                                    if let areaSize = shape.areaSize {
                                        document.updateTextAreaSizeInUnified(id: shape.id, areaSize: areaSize)
                                    }
                                    document.updateTextBoundsInUnified(id: shape.id, bounds: shape.bounds)
                                }
                                document.triggerLayerUpdate(for: layerIndex)
                                break
                            }
                        }
                    }
                }
            }
        )

        updateValuesFromSelection()
    }
}
