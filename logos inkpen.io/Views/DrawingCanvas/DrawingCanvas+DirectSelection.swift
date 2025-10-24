import SwiftUI
import Combine

extension DrawingCanvas {

    internal func selectIndividualAnchorPointOrHandle(at location: CGPoint, tolerance: Double) -> Bool {
        for shapeID in selectedObjectIDs {
            if let object = document.snapshot.objects[shapeID],
               case .shape(let shape) = object.objectType {
                // Use O(1) layer index lookup
                let layer = object.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[object.layerIndex] : nil

                if layer?.isLocked == true || shape.isLocked {
                    selectedObjectIDs.removeAll()
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    syncDirectSelectionWithDocument()
                    return true
                }

                    if shape.isGroupContainer {
                        for groupedShape in shape.groupedShapes {
                            if !groupedShape.isVisible { continue }

                            if checkAnchorPointsInShape(groupedShape, at: location, tolerance: tolerance) {
                                return true
                            }
                        }
                    } else {
                        if checkAnchorPointsInShape(shape, at: location, tolerance: tolerance) {
                            return true
                        }
                    }
            }
        }

        return false
    }

    private func checkAnchorPointsInShape(_ shape: VectorShape, at location: CGPoint, tolerance: Double) -> Bool {
        let pointSelectionRadius: Double = 6.0 / document.viewState.zoomLevel
        let handleSelectionRadius: Double = 4.0 / document.viewState.zoomLevel

        // Always use Metal GPU for point selection
        var points: [CGPoint] = []
        var elementIndices: [Int] = []

        for (elementIndex, element) in shape.path.elements.enumerated() {
            switch element {
            case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                points.append(CGPoint(x: to.x, y: to.y))
                elementIndices.append(elementIndex)
            case .close:
                continue
            }
        }

        guard !points.isEmpty else { return false }

        if let nearestIndex = MetalComputeEngine.shared.findNearestPointGPU(
            points: points,
            tapLocation: location,
            selectionRadius: pointSelectionRadius,
            transform: shape.transform
        ) {
            let elementIndex = elementIndices[nearestIndex]
            let pointID = PointID(
                shapeID: shape.id,
                pathIndex: 0,
                elementIndex: elementIndex
            )

            if isShiftPressed && selectedPoints.contains(pointID) {
                let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
                let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
                selectedPoints.remove(pointID)
                for coincidentPoint in coincidentPoints {
                    selectedPoints.remove(coincidentPoint)
                }
                for endpointID in closedPathEndpoints {
                    selectedPoints.remove(endpointID)
                }
            } else {
                selectPointWithCoincidents(pointID, addToSelection: isShiftPressed)
            }
            return true
        }

        // Always use Metal GPU for handle selection
        var handlePoints: [CGPoint] = []
        var anchorPoints: [CGPoint] = []
        var handleMetadata: [(elementIndex: Int, handleType: HandleType)] = []

        for (elementIndex, element) in shape.path.elements.enumerated() {
            switch element {
            case .curve(let to, _, let control2):
                let handle2Collapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                if !handle2Collapsed {
                    handlePoints.append(CGPoint(x: control2.x, y: control2.y))
                    anchorPoints.append(CGPoint(x: to.x, y: to.y))
                    handleMetadata.append((elementIndex: elementIndex, handleType: .control2))
                }

                if elementIndex + 1 < shape.path.elements.count,
                   case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                    let handle1Collapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                    if !handle1Collapsed {
                        handlePoints.append(CGPoint(x: nextControl1.x, y: nextControl1.y))
                        anchorPoints.append(CGPoint(x: to.x, y: to.y))
                        handleMetadata.append((elementIndex: elementIndex + 1, handleType: .control1))
                    }
                }

            case .quadCurve(let to, let control):
                let quadHandleCollapsed = (abs(control.x - to.x) < 0.1 && abs(control.y - to.y) < 0.1)
                if !quadHandleCollapsed {
                    handlePoints.append(CGPoint(x: control.x, y: control.y))
                    anchorPoints.append(CGPoint(x: to.x, y: to.y))
                    handleMetadata.append((elementIndex: elementIndex, handleType: .control1))
                }

            case .move(let to), .line(let to):
                if elementIndex + 1 < shape.path.elements.count,
                   case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                    let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                    if !outgoingHandleCollapsed {
                        handlePoints.append(CGPoint(x: nextControl1.x, y: nextControl1.y))
                        anchorPoints.append(CGPoint(x: to.x, y: to.y))
                        handleMetadata.append((elementIndex: elementIndex + 1, handleType: .control1))
                    }
                }

            case .close:
                continue
            }
        }

        if !handlePoints.isEmpty, let nearestIndex = MetalComputeEngine.shared.findNearestHandleGPU(
            handlePoints: handlePoints,
            anchorPoints: anchorPoints,
            tapLocation: location,
            selectionRadius: handleSelectionRadius,
            transform: shape.transform
        ) {
            let metadata = handleMetadata[nearestIndex]
            let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: metadata.elementIndex, handleType: metadata.handleType)

            if isShiftPressed && selectedHandles.contains(handleID) {
                selectedHandles.remove(handleID)
            } else {
                if !isShiftPressed {
                    selectedHandles.removeAll()
                    selectedPoints.removeAll()
                    visibleHandles.removeAll()
                }
                selectedHandles.insert(handleID)

                selectCoincidentHandles(for: handleID, shape: shape)
            }
            return true
        }

        return false
    }

    internal func directSelectWholeShape(at location: CGPoint) -> Bool {
        // Use same optimized hit test as selection tool
        guard let hitObject = findObjectAtLocationOptimized(location) else {
            return false
        }

        let shape = hitObject.shape

        // Check if locked using O(1) index lookup
        let layer = hitObject.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[hitObject.layerIndex] : nil
        if layer?.isLocked == true || shape.isLocked {
            selectedObjectIDs.removeAll()
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            syncDirectSelectionWithDocument()
            return true
        }

        selectedObjectIDs.removeAll()
        selectedObjectIDs.insert(shape.id)
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        syncDirectSelectionWithDocument()
        return true
    }

    internal func handleDirectSelectionTap(at location: CGPoint) {

        let screenTolerance: Double = 15.0
        let tolerance: Double = screenTolerance / document.viewState.zoomLevel
        var foundSelection = false

        if !selectedObjectIDs.isEmpty {
            foundSelection = selectIndividualAnchorPointOrHandle(at: location, tolerance: tolerance)
        }

        if !foundSelection {
            foundSelection = directSelectWholeShape(at: location)
        }

        if !foundSelection {
            Log.error("❌ Clicked empty space - clearing all direct selections", category: .error)
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            visibleHandles.removeAll()
            selectedObjectIDs.removeAll()
            syncDirectSelectionWithDocument()
        }
    }

    private func selectCoincidentHandles(for handleID: HandleID, shape: VectorShape) {
        let anchorPoint: CGPoint?
        let pointIndex: Int

        if handleID.handleType == .control1 {
            pointIndex = handleID.elementIndex - 1
            if pointIndex >= 0 && pointIndex < shape.path.elements.count {
                switch shape.path.elements[pointIndex] {
                case .move(let to), .line(let to):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                case .close:
                    anchorPoint = nil
                }
            } else {
                return
            }
        } else if handleID.handleType == .control2 {
            pointIndex = handleID.elementIndex
            if pointIndex < shape.path.elements.count {
                switch shape.path.elements[pointIndex] {
                case .curve(let to, _, _):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                case .quadCurve(let to, _):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                default:
                    anchorPoint = nil
                }
            } else {
                return
            }
        } else {
            return
        }

        guard let anchor = anchorPoint else { return }

        let tolerance = 1.0
        for (index, element) in shape.path.elements.enumerated() {
            if index == pointIndex { continue }

            let elementPoint: CGPoint?
            switch element {
            case .move(let to), .line(let to):
                elementPoint = CGPoint(x: to.x, y: to.y)
            case .curve(let to, _, _), .quadCurve(let to, _):
                elementPoint = CGPoint(x: to.x, y: to.y)
            case .close:
                elementPoint = nil
            }

            if let point = elementPoint {
                let distance = sqrt(pow(anchor.x - point.x, 2) + pow(anchor.y - point.y, 2))
                if distance <= tolerance {

                    if case .curve(_, _, let control2) = element {
                        let handle2Collapsed = (abs(control2.x - point.x) < 0.1 && abs(control2.y - point.y) < 0.1)
                        if !handle2Collapsed {
                            let coincidentHandleID = HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: index,
                                handleType: .control2
                            )
                            if coincidentHandleID != handleID {
                                visibleHandles.insert(coincidentHandleID)
                            }
                        }
                    }

                    let nextIndex = index + 1
                    if nextIndex < shape.path.elements.count {
                        if case .curve(_, let control1, _) = shape.path.elements[nextIndex] {
                            let handle1Collapsed = (abs(control1.x - point.x) < 0.1 && abs(control1.y - point.y) < 0.1)
                            if !handle1Collapsed {
                                let coincidentHandleID = HandleID(
                                    shapeID: shape.id,
                                    pathIndex: 0,
                                    elementIndex: nextIndex,
                                    handleType: .control1
                                )
                                if coincidentHandleID != handleID {
                                    visibleHandles.insert(coincidentHandleID)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
