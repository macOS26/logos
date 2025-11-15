import SwiftUI

struct PathOperationsPanel: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    let document: VectorDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Path Operations")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()

                Button {
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Professional Path Operations")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                Text("Shape Modes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach([PathfinderOperation.union, .minusFront, .intersect, .exclude], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Path Operations Effects")
                        .font(.caption)
                    .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                                            ForEach([PathfinderOperation.mosaic, .cut, .merge, .separate, .crop, .dieline, .kick, .combine], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            ProfessionalOffsetPathSection(
                selectedObjectIDs: selectedObjectIDs,
                document: document
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Path Cleanup")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                VStack(spacing: 8) {
                    Button {
                        mergeCoincidentPointsInSelectedShapes()
                    } label: {
                        Text("Merge Points")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        mergeCoincidentPointsInSelectedShapes()
                    }
                    .help("Merge coincident points in selected shapes (excluding start and end points)")

                    Button {
                        removeOverlapFromSelectedShapes()
                    } label: {
                        Text("Remove Overlap")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        removeOverlapFromSelectedShapes()
                    }
                    .help("Remove self-intersections and overlapping areas within selected shapes")

                    Button {
                        removeOverlapFromAllShapes()
                    } label: {
                        Text("Remove All Overlaps")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        removeOverlapFromAllShapes()
                    }
                    .help("Remove overlaps from all shapes in the document")
                }
                .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Clipping Masks")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow Content Selection")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("Enable selection inside clipping masks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { AppState.shared.enableClippingMaskContentSelection },
                        set: { AppState.shared.enableClippingMaskContentSelection = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 8) {
                    Button {
                        document.makeClippingMaskFromSelection()
                    } label: {
                        Text("Make Clipping Mask")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        document.makeClippingMaskFromSelection()
                    }

                    Button {
                        document.releaseClippingMaskForSelection()
                    } label: {
                        Text("Release Clipping Mask")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        document.releaseClippingMaskForSelection()
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
                }
            }
        }
    }

    private func canPerformOperation(_ operation: PathfinderOperation) -> Bool {
        let selectedShapes = document.getSelectedShapes()
        let paths = selectedShapes.map { $0.path.cgPath }
        return ProfessionalPathOperations.canPerformOperation(operation, on: paths)
    }

    private func performPathfinderOperation(_ operation: PathfinderOperation) {

        let selectedShapes = document.getSelectedShapesInStackingOrder()
        guard !selectedShapes.isEmpty else {
            Log.error("❌ No shapes selected for pathfinder operation", category: .error)
            return
        }

        let paths = selectedShapes.map { $0.path.cgPath }

        guard ProfessionalPathOperations.canPerformOperation(operation, on: paths) else {
            Log.error("❌ Cannot perform \(operation.rawValue) on selected shapes", category: .error)
            return
        }

        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for shape in selectedShapes {
            oldShapes[shape.id] = shape
            objectIDs.append(shape.id)
        }

        var resultShapes: [VectorShape] = []

        switch operation {
        case .union:
            if let unionPath = ProfessionalPathOperations.union(paths) {
                guard let topmostShape = selectedShapes.last else {
                    Log.error("❌ UNION: No topmost shape found", category: .general)
                    return
                }
                let unionShape = VectorShape(
                    name: "Union Shape",
                    path: VectorPath(cgPath: unionPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [unionShape]
            }

        case .minusFront:
            guard selectedShapes.count >= 2 else {
                Log.error("❌ PUNCH requires at least 2 shapes", category: .error)
                return
            }

            guard let backShape = selectedShapes.first else {
                Log.error("❌ PUNCH: No back shape found", category: .general)
                return
            }
            let frontShapes = Array(selectedShapes.dropFirst())
            var resultPath = backShape.path.cgPath

            for frontShape in frontShapes {
                if let subtractedPath = ProfessionalPathOperations.minusFront(frontShape.path.cgPath, from: resultPath) {
                    resultPath = subtractedPath
                }
            }

            let resultShape = VectorShape(
                name: "Punch Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: backShape.strokeStyle,
                fillStyle: backShape.fillStyle,
                transform: .identity,
                opacity: backShape.opacity
            )
            resultShapes = [resultShape]

        case .intersect:
            guard selectedShapes.count == 2 else {
                Log.error("❌ INTERSECT requires exactly 2 shapes", category: .error)
                return
            }

            if let intersectedPath = ProfessionalPathOperations.intersect(paths[0], paths[1]) {
                guard let topmostShape = selectedShapes.last else {
                    Log.error("❌ INTERSECT: No topmost shape found", category: .general)
                    return
                }
                let intersectedShape = VectorShape(
                    name: "Intersected Shape",
                    path: VectorPath(cgPath: intersectedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [intersectedShape]
            }

        case .exclude:
            guard selectedShapes.count == 2 else {
                Log.error("❌ EXCLUDE requires exactly 2 shapes", category: .error)
                return
            }

            let excludedPaths = ProfessionalPathOperations.exclude(paths[0], paths[1])
            guard let topmostShape = selectedShapes.last else {
                Log.error("❌ EXCLUDE: No topmost shape found", category: .general)
                return
            }

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

        case .mosaic:
            let mosaicResults = CoreGraphicsPathOperations.splitWithShapeTracking(paths, using: .winding)

            for (index, (mosaicPath, originalShapeIndex)) in mosaicResults.enumerated() {
                let originalShape = selectedShapes[originalShapeIndex]
                                let mosaicShape = VectorShape(
                name: "Mosaic Piece \(index + 1)",
                    path: VectorPath(cgPath: mosaicPath),
                    strokeStyle: originalShape.strokeStyle,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(mosaicShape)
            }

        case .cut:
            let cutResults = CoreGraphicsPathOperations.cutWithShapeTracking(paths, using: .winding)
            var shapeCounters: [Int: Int] = [:]

            for (cutPath, originalShapeIndex) in cutResults {
                guard originalShapeIndex < selectedShapes.count else { continue }

                let originalShape = selectedShapes[originalShapeIndex]

                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                let cutShape = VectorShape(
                    name: pieceNumber > 1 ? "Cut \(originalShape.name) (\(pieceNumber))" : "Cut \(originalShape.name)",
                    path: VectorPath(cgPath: cutPath),
                    strokeStyle: nil,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(cutShape)
            }

        case .merge:
            let colors = selectedShapes.compactMap { $0.fillStyle?.color ?? .clear }

            guard colors.count == selectedShapes.count else {
                Log.error("❌ MERGE: Could not extract colors from all shapes", category: .error)
                return
            }

            let mergeResults = ProfessionalPathOperations.professionalMergeWithShapeTracking(paths, colors: colors)
            var shapeCounters: [Int: Int] = [:]

            for (mergedPath, originalShapeIndex) in mergeResults {
                guard originalShapeIndex < selectedShapes.count else { continue }

                let originalShape = selectedShapes[originalShapeIndex]

                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                let mergedShape = VectorShape(
                    name: pieceNumber > 1 ? "Merged \(originalShape.name) (\(pieceNumber))" : "Merged \(originalShape.name)",
                    path: VectorPath(cgPath: mergedPath),
                    strokeStyle: nil,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(mergedShape)
            }

        case .crop:
            let cropResults = ProfessionalPathOperations.professionalCropWithShapeTracking(paths)
            var shapeCounters: [Int: Int] = [:]

            for (croppedPath, originalShapeIndex, isInvisibleCropShape) in cropResults {
                guard originalShapeIndex < selectedShapes.count else { continue }

                let originalShape = selectedShapes[originalShapeIndex]

                if isInvisibleCropShape {
                    let invisibleCropShape = VectorShape(
                        name: "Crop Boundary (\(originalShape.name))",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil,
                        fillStyle: nil,
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(invisibleCropShape)
                } else {
                    shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                    let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                    let croppedShape = VectorShape(
                        name: pieceNumber > 1 ? "Cropped \(originalShape.name) (\(pieceNumber))" : "Cropped \(originalShape.name)",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil,
                        fillStyle: originalShape.fillStyle,
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(croppedShape)
                }
            }

        case .dieline:
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
                    fillStyle: nil,
                    transform: .identity,
                    opacity: 1.0
                )
                resultShapes.append(dielineShape)
            }

        case .separate:
            var separatedShapes: [VectorShape] = []

            for (_, shape) in selectedShapes.enumerated() {
                let components = CoreGraphicsPathOperations.componentsSeparated(shape.path.cgPath, using: .winding)

                if components.count <= 1 {
                    separatedShapes.append(shape)
                } else {
                    for (componentIndex, component) in components.enumerated() {
                        let separatedShape = VectorShape(
                            name: components.count > 1 ? "\(shape.name) Component \(componentIndex + 1)" : shape.name,
                            path: VectorPath(cgPath: component),
                            strokeStyle: shape.strokeStyle,
                            fillStyle: shape.fillStyle,
                            transform: .identity,
                            opacity: shape.opacity
                        )
                        separatedShapes.append(separatedShape)
                    }
                }
            }

            resultShapes = separatedShapes

        case .kick:
            guard selectedShapes.count >= 2 else {
                Log.error("❌ KICK requires at least 2 shapes", category: .error)
                return
            }

            guard let frontShape = selectedShapes.last else {
                Log.error("❌ KICK: No front shape found", category: .general)
                return
            }
            let backShapes = Array(selectedShapes.dropLast())
            var resultPath = frontShape.path.cgPath

            for backShape in backShapes {
                if let subtractedPath = ProfessionalPathOperations.kick(resultPath, from: backShape.path.cgPath) {
                    resultPath = subtractedPath
                }
            }

            let resultShape = VectorShape(
                name: "Kick Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: frontShape.strokeStyle,
                fillStyle: frontShape.fillStyle,
                transform: .identity,
                opacity: frontShape.opacity
            )
            resultShapes = [resultShape]

        case .combine:
            // Union all selected objects regardless of color
            if let unionPath = ProfessionalPathOperations.union(paths) {
                guard let topmostShape = selectedShapes.last else {
                    Log.error("❌ COMBINE: No topmost shape found", category: .general)
                    return
                }
                let combinedShape = VectorShape(
                    name: "Combined Shape",
                    path: VectorPath(cgPath: unionPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [combinedShape]
            }
        }

        guard !resultShapes.isEmpty else {
            Log.error("❌ Pathfinder operation \(operation.rawValue) produced no results", category: .error)
            return
        }

        document.removeSelectedObjects()

        var newShapes: [UUID: VectorShape] = [:]

        for resultShape in resultShapes {
            document.addShape(resultShape)
            document.selectShape(resultShape.id)
            objectIDs.append(resultShape.id)
            newShapes[resultShape.id] = resultShape
        }

        let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
        document.commandManager.execute(command)
    }

    private func removeOverlapFromSelectedShapes() {
        guard !document.viewState.selectedObjectIDs.isEmpty else { return }

        let selectedShapes = document.getSelectedShapes()
        var processedCount = 0

        for shape in selectedShapes {
            if removeOverlapFromShape(shape) {
                processedCount += 1
            }
        }

    }

    private func removeOverlapFromAllShapes() {
        let allShapes = document.snapshot.objects.values.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType {
                return shape
            }
            return nil
        }
        guard !allShapes.isEmpty else { return }

        var processedCount = 0

        for shape in allShapes {
            if removeOverlapFromShape(shape) {
                processedCount += 1
            }
        }

    }

    @discardableResult
    private func removeOverlapFromShape(_ shape: VectorShape) -> Bool {
        let originalPath = shape.path.cgPath

        guard !originalPath.isEmpty && !originalPath.boundingBox.isNull && !originalPath.boundingBox.isInfinite else {
            return false
        }

        if let cleanedPath = CoreGraphicsPathOperations.union(originalPath, originalPath) {
            guard !cleanedPath.isEmpty && !cleanedPath.boundingBox.isNull && !cleanedPath.boundingBox.isInfinite else {
                return false
            }

            if let layerIndex = document.snapshot.layers.firstIndex(where: { layer in
                document.getShapesForLayer(document.snapshot.layers.firstIndex(of: layer) ?? -1).contains { $0.id == shape.id }
            }),
               document.getShapesForLayer(layerIndex).contains(where: { $0.id == shape.id }) {

                document.updateShapePathUnified(id: shape.id, path: VectorPath(cgPath: cleanedPath))

                return true
            }
        }

        Log.error("❌ REMOVE OVERLAP: Failed to clean shape: \(shape.name)", category: .error)
        return false
    }

    private func mergeCoincidentPointsInSelectedShapes() {
        guard !document.viewState.selectedObjectIDs.isEmpty else {
            Log.info("No shapes selected", category: .general)
            return
        }

        let selectedShapes = document.getSelectedShapes()
        let tolerance: Double = 1.0

        Log.info("Merging ALL coincident points in \(selectedShapes.count) shapes (tolerance: \(tolerance))", category: .general)

        for shape in selectedShapes {
            let originalCount = shape.path.elements.count
            let cleanedPath = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: shape.path, tolerance: tolerance)
            let newCount = cleanedPath.elements.count

            Log.info("Shape '\(shape.name)': \(originalCount) -> \(newCount) elements (removed \(originalCount - newCount))", category: .general)

            if newCount != originalCount {
                document.updateShapePathUnified(id: shape.id, path: cleanedPath)
            }
        }
    }

}
