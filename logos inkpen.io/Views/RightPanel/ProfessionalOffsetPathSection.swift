import SwiftUI

struct ProfessionalOffsetPathSection: View {
    let selectedObjectIDs: Set<UUID>
    let document: VectorDocument
    @State private var offsetDistance: Int = 10
    @State private var selectedJoinType: JoinType = .round
    @State private var miterLimit: Double = 4.0
    @State private var showAdvanced: Bool = true
    @State private var keepOriginalPath: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .buttonStyle(BorderlessButtonStyle())

                Spacer()

                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)

            if showAdvanced {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Offset:")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(offsetDistance)pt")
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .monospacedDigit()
                        }

                        ZStack {

                            Slider(value: Binding(
                                get: { Double(offsetDistance) },
                                set: { offsetDistance = Int($0) }
                            ), in: -72...72)
                            .controlSize(.regular)
                            .tint(Color.clear)

                            Capsule()
                                .fill(
                                    SwiftUI.LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue,
                                            Color.clear,
                                            Color.red
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 6)
                                .allowsHitTesting(false)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep Original Path")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("Preserve original when creating offset")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $keepOriginalPath)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .controlSize(.small)
                    }
                    .help("Keep the original path when creating offset (Professional default)")

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
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .help(joinType.description)
                            }
                        }
                    }

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

                            ZStack {
                                Capsule()
                                    .fill(Color.white)
                                    .frame(height: 6)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                                    )

                                Slider(value: $miterLimit, in: 1.0...20.0) {
                                    Text("Miter Limit")
                                }
                                .controlSize(.regular)
                                .tint(Color.clear)

                                Capsule()
                                    .fill(Color.blue)
                                    .frame(height: 6)
                                    .allowsHitTesting(false)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        performOffsetPath()
                    } label: {
                        Text("Offset Path")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .onTapGesture {
                        performOffsetPath()
                    }
                    .help("Create offset path with current settings (⌘⌥O)")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func canPerformOffset() -> Bool {
        return !selectedObjectIDs.isEmpty
    }

    private func performOffsetPath() {
        guard !selectedObjectIDs.isEmpty else { return }

        let selectedShapes = document.getSelectedShapes()
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for shape in selectedShapes {
            oldShapes[shape.id] = shape
            objectIDs.append(shape.id)
        }

        var newOffsetShapeIDs: Set<UUID> = []
        var originalShapeIndices: [UUID: Int] = [:]
        if let layerIndex = document.selectedLayerIndex {
            let shapes = document.getShapesForLayer(layerIndex)
            for (index, shape) in shapes.enumerated() {
                if selectedObjectIDs.contains(shape.id) {
                    originalShapeIndices[shape.id] = index
                }
            }
        }

        for shape in selectedShapes {

            let offsetValue = CGFloat(offsetDistance)
            let offsetPath = shape.path.cgPath.copy(strokingWithWidth: abs(offsetValue) * 2.0,
                                                    lineCap: .round,
                                                    lineJoin: mapJoinTypeToCoreGraphics(selectedJoinType),
                                                    miterLimit: CGFloat(miterLimit))

            var finalPath: CGPath

            if offsetDistance >= 0 {
                if let unionResult = CoreGraphicsPathOperations.union(shape.path.cgPath, offsetPath, using: .winding) {
                    finalPath = unionResult
                } else {
                    finalPath = offsetPath
                }
            } else {
                if let subtractResult = CoreGraphicsPathOperations.subtract(offsetPath, from: shape.path.cgPath, using: .winding) {
                    finalPath = subtractResult
                } else {
                    finalPath = shape.path.cgPath
                }
            }

                let offsetVectorPath = VectorPath(cgPath: finalPath)
                let offsetShape = VectorShape(
                    name: "\(shape.name) Offset \(offsetDistance > 0 ? "+" : "")\(offsetDistance)pt",
                    path: offsetVectorPath,
                    strokeStyle: shape.strokeStyle,
                    fillStyle: shape.fillStyle,
                    transform: shape.transform,
                    opacity: shape.opacity
                )

                if offsetDistance >= 0 {
                    if let layerIndex = document.selectedLayerIndex {
                        document.addShapeBehindInUnifiedSystem(offsetShape, layerIndex: layerIndex, behindShapeIDs: [shape.id])
                    }
                } else {
                    document.addShape(offsetShape)
                }

                newOffsetShapeIDs.insert(offsetShape.id)
                objectIDs.append(offsetShape.id)
                newShapes[offsetShape.id] = offsetShape
        }

        if keepOriginalPath {
            if offsetDistance >= 0 {
                for shape in selectedShapes {
                    newShapes[shape.id] = shape
                }
            } else {
                for shape in selectedShapes {
                    newShapes[shape.id] = shape
                }
            }
        } else {
            document.removeSelectedShapes()
        }

        document.viewState.selectedObjectIDs = newOffsetShapeIDs
        let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
        document.commandManager.execute(command)
    }

    private func mapJoinTypeToCoreGraphics(_ joinType: JoinType) -> CGLineJoin {
        switch joinType {
        case .round: return .round
        case .miter: return .miter
        case .bevel: return .bevel
        case .square: return .miter
        }
    }

    private func findOutsidePath(from trimmedPaths: [CGPath], original: CGPath, offset: CGPath) -> CGPath? {
        guard !trimmedPaths.isEmpty else { return nil }

        let offsetBounds = offset.boundingBoxOfPath
        var bestPath: CGPath?
        var bestScore: CGFloat = 0

        for path in trimmedPaths {
            let pathBounds = path.boundingBoxOfPath
            let pathArea = pathBounds.width * pathBounds.height
            let areaScore = pathArea
            let proximityScore = pathBounds.intersection(offsetBounds).width * pathBounds.intersection(offsetBounds).height
            let totalScore = areaScore + proximityScore * 2.0

            if totalScore > bestScore {
                bestScore = totalScore
                bestPath = path
            }
        }

        return bestPath ?? trimmedPaths.first
    }
}
