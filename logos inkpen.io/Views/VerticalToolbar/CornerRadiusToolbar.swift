import SwiftUI
import Combine

struct CornerRadiusToolbar: View {
    @ObservedObject var document: VectorDocument
    @State private var cornerValues: [Double] = []
    @State private var cornerCount: Int = 0

    var body: some View {
        Group {
            if let shape = getSelectedShape(), isRectangleShape(shape) && cornerCount == 4 {
                cornerRadiusDisplay
            }
        }
        .onAppear {
            updateCornerValues()
        }
        .onChange(of: document.selectedShapeIDs) { _, _ in
            updateCornerValues()
        }
        .onChange(of: document.layers) { _, _ in
            updateCornerValues()
        }
        .onReceive(document.objectWillChange) { _ in
            updateCornerValues()
        }
    }

    @ViewBuilder
    private var cornerRadiusDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: shapeIcon)
                .foregroundColor(Color.ui.secondaryText)
                .font(.caption)
                .offset(y: 2)

            cornerFieldsView
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.ui.controlBackground)
        .cornerRadius(6)
    }

    @ViewBuilder
    private var cornerFieldsView: some View {
        if cornerCount == 4 {
            HStack(spacing: 4) {
                ForEach(0..<cornerCount, id: \.self) { index in
                    cornerField(index: index, label: "\(index + 1)")
                }
            }
        }
    }

    @ViewBuilder
    private func cornerField(index: Int, label: String) -> some View {
        let isRounded = getSelectedShape().map { isCornerRounded(shape: $0, cornerIndex: index) } ?? false
        let cornerValue = cornerValues[safe: index] ?? 0.0

        HStack(spacing: 2) {
            HStack(spacing: 1) {
                Text(label + ":")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)

                if isRounded && cornerValue > 0 {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 4))
                        .foregroundColor(Color.ui.primaryBlue)
                        .offset(y: 2)
                } else {
                    Image(systemName: "square.fill")
                        .font(.system(size: 4))
                        .foregroundColor(Color.ui.standardBorder)
                        .offset(y: 2)
                }
            }

            TextField("0", text: Binding(
                get: {
                    if let shape = getSelectedShape() {
                        let currentRadius = shape.cornerRadii[safe: index] ?? 0.0
                        return String(format: "%.0f", currentRadius)
                    }
                    return "0"
                },
                set: { newValue in
                    if let value = Double(newValue) {
                        updateCornerRadius(index: index, value: max(0, value))
                    }
                }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 50)
            .font(.caption)
            .background(isRounded && (getSelectedShape()?.cornerRadii[safe: index] ?? 0.0) > 0 ? InkPenUIColors.shared.veryLightBlueBackground : Color.clear)
        }
    }

    private var shapeIcon: String {
        switch cornerCount {
        case 3: return "triangle"
        case 4: return "rectangle"
        case 5: return "pentagon"
        case 6: return "hexagon"
        default: return "circle"
        }
    }

    private func updateCornerValues() {
        guard let selectedShape = getSelectedShape() else {
            cornerValues = []
            cornerCount = 0
            return
        }

        cornerCount = countShapeCorners(shape: selectedShape)

        let currentRadii = selectedShape.cornerRadii
        cornerValues = Array(0..<cornerCount).map { index in
            currentRadii[safe: index] ?? 0.0
        }
    }

    private func countShapeCorners(shape: VectorShape) -> Int {
        let shapeName = shape.name.lowercased()

        if shapeName.contains("triangle") {
            return 3
        } else if shapeName == "rectangle" || shapeName == "square" ||
                  shapeName == "rounded rectangle" || shapeName == "pill" {
            return 4
        }

        let elements = shape.path.elements
        var lineCount = 0
        var curveCount = 0

        for element in elements {
            switch element {
            case .move, .close:
                break
            case .line:
                lineCount += 1
            case .curve, .quadCurve:
                curveCount += 1
            }
        }

        let totalSegments = lineCount + curveCount

        if totalSegments == 3 {
            return 3
        } else if totalSegments == 4 {
            return 4
        } else if totalSegments == 8 && curveCount == 4 {
            return 4
        } else if curveCount == 4 && lineCount == 0 {
            return 4
        }

        return 0
    }

    private func getSelectedShape() -> VectorShape? {
        guard document.selectedShapeIDs.count == 1,
              let selectedID = document.selectedShapeIDs.first else { return nil }
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               shape.id == selectedID {
                return shape
            }
        }
        return nil
    }

    private func isCornerRounded(shape: VectorShape, cornerIndex: Int) -> Bool {
        let elements = shape.path.elements
        var lineSegments: [PathElement] = []
        var curves: [PathElement] = []

        for element in elements {
            switch element {
            case .line:
                lineSegments.append(element)
            case .curve, .quadCurve:
                curves.append(element)
            case .move, .close:
                break
            }
        }


        if curves.count == cornerCount && cornerIndex < curves.count {
            return true
        }

        if curves.count == 0 {
            return false
        }

        let radius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
        return radius > 0.0
    }

    private func updateCornerRadius(index: Int, value: Double) {
        guard let selectedShape = getSelectedShape() else { return }

        // Capture old shape state
        let oldShape = selectedShape

        for layerIndex in document.layers.indices {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShape.id }),
               var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {

                if !shape.isRoundedRectangle && isRectangleShape(shape) {

                    let pathBounds = shape.path.cgPath.boundingBox
                    shape.originalBounds = pathBounds
                    shape.isRoundedRectangle = true

                    if shape.cornerRadii.isEmpty {
                        shape.cornerRadii = [0.0, 0.0, 0.0, 0.0]
                    }
                }

                var updatedRadii = shape.cornerRadii

                while updatedRadii.count <= index {
                    updatedRadii.append(0.0)
                }
                updatedRadii[index] = value

                shape.cornerRadii = updatedRadii

                let currentBounds = shape.path.cgPath.boundingBox
                let newPath = GeometricShapes.createRoundedRectPathWithIndividualCorners(
                    rect: currentBounds,
                    cornerRadii: updatedRadii
                )

                document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: updatedRadii, path: newPath)

                // Capture new shape state
                if let newShape = getSelectedShape() {
                    let command = ShapeModificationCommand(
                        objectIDs: [selectedShape.id],
                        oldShapes: [selectedShape.id: oldShape],
                        newShapes: [selectedShape.id: newShape]
                    )
                    document.commandManager.execute(command)
                }

                break
            }
        }

        updateCornerValues()
    }

    private func isRectangleShape(_ shape: VectorShape) -> Bool {
        let shapeName = shape.name.lowercased()
        return shapeName == "rectangle" || shapeName == "square" ||
               shapeName == "rounded rectangle" || shapeName == "pill"
    }
}

#Preview {
    CornerRadiusToolbar(document: VectorDocument())
        .padding()
}
