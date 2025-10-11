import SwiftUI
import Combine


struct ProfessionalOffsetPathSection: View {
    @ObservedObject var document: VectorDocument
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

                        Slider(value: Binding(
                            get: { Double(offsetDistance) },
                            set: { offsetDistance = Int($0) }
                        ), in: -30...30) {
                            Text("Offset Distance")
                        }
                        .controlSize(.regular)
                        .tint(.blue)
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

                            Slider(value: $miterLimit, in: 1.0...20.0) {
                                Text("Miter Limit")
                            }
                            .controlSize(.regular)
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
        return !document.selectedShapeIDs.isEmpty
    }


    private func performOffsetPath() {
        guard !document.selectedShapeIDs.isEmpty else { return }


        document.saveToUndoStack()

        let selectedShapes = document.getSelectedShapes()
        var newOffsetShapeIDs: Set<UUID> = []

        var originalShapeIndices: [UUID: Int] = [:]
        if let layerIndex = document.selectedLayerIndex {
            let shapes = document.getShapesForLayer(layerIndex)
            for (index, shape) in shapes.enumerated() {
                if document.selectedShapeIDs.contains(shape.id) {
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
                        document.layers[layerIndex].addShape(offsetShape)
                        document.addShapeBehindInUnifiedSystem(offsetShape, layerIndex: layerIndex, behindShapeIDs: [shape.id])
                    }
                } else {
                    document.addShape(offsetShape)
                }

                newOffsetShapeIDs.insert(offsetShape.id)

        }

        if keepOriginalPath {
            if offsetDistance >= 0 {
            } else {
            }
        } else {
            document.removeSelectedShapes()
        }

        document.selectedShapeIDs = newOffsetShapeIDs

        document.updateUnifiedObjectsOptimized()

        document.objectWillChange.send()

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
