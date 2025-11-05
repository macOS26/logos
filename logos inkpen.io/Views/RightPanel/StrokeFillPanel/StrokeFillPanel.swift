import SwiftUI
import Combine

struct StrokeFillPanel: View {
    @Binding var snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    let selectedPoints: Set<PointID>
    let selectedHandles: Set<HandleID>
    let activeColorTarget: ColorTarget
    @Binding var colorMode: ColorMode
    @Binding var defaultFillColor: VectorColor
    @Binding var defaultStrokeColor: VectorColor
    @Binding var defaultFillOpacity: Double
    @Binding var defaultStrokeOpacity: Double
    @Binding var defaultStrokeWidth: Double
    let strokeDefaults: StrokeDefaults
    let currentSwatches: [VectorColor]
    let currentTool: DrawingTool
    let hasPressureInput: Bool
    let changeToken: UUID
    let onTriggerLayerUpdates: (Set<Int>) -> Void
    let onAddColorSwatch: (VectorColor) -> Void
    let onRemoveColorSwatch: (VectorColor) -> Void
    let onSetActiveColor: (VectorColor) -> Void
    @Binding var colorDeltaColor: VectorColor?
    @Binding var colorDeltaOpacity: Double?
    @Binding var strokeDeltaWidth: Double?
    let onSetActiveColorTarget: (ColorTarget) -> Void
    let onUpdateStrokeDefaults: (StrokeDefaults) -> Void
    let onOutlineSelectedStrokes: () -> Void
    let onDuplicateSelectedShapes: () -> Void
    let onUpdateObjectOpacity: (UUID, Double, ColorTarget) -> Void
    let onUpdateObjectStrokeWidth: (UUID, Double) -> Void
    let onUpdateFillOpacityLive: (Double, Bool) -> Void
    let onUpdateStrokeOpacityLive: (Double, Bool) -> Void
    let onUpdateStrokeWidthLive: (Double, Bool) -> Void
    let onUpdateStrokePlacement: (StrokePlacement) -> Void
    let onUpdateStrokeLineJoin: (CGLineJoin) -> Void
    let onUpdateStrokeLineCap: (CGLineCap) -> Void
    let onUpdateStrokeMiterLimit: (Double) -> Void
    let onUpdateStrokeMiterLimitDirectNoUndo: (Double) -> Void
    let onUpdateStrokeScaleWithTransform: (Bool) -> Void
    let onUpdateImageOpacity: (Double) -> Void
    let onApplyFillToSelectedShapes: (VectorColor, Double) -> Void
    let onUpdateShapeStrokePlacementInUnified: (UUID, StrokePlacement) -> Void

    @Environment(AppState.self) private var appState
    @State private var fillOpacityState: Double = 1.0
    @State private var strokeOpacityState: Double = 1.0
    @State private var strokeWidthState: Double = 1.0
    @State private var strokePlacementState: StrokePlacement = .center
    @State private var strokeMiterLimitState: Double = 10.0
    @State private var selectedImageOpacityState: Double = 1.0
    @State private var isDragging: Bool = false

    // Detect current anchor type from selected points or handles
    private var currentAnchorType: AnchorPointType {
        var detectedTypes = Set<AnchorPointType>()

        // First check selected points
        for pointID in selectedPoints {
            guard let object = snapshot.objects[pointID.shapeID],
                  case .shape(let shape) = object.objectType,
                  pointID.elementIndex < shape.path.elements.count else {
                continue
            }

            let type = detectAnchorType(for: pointID, in: shape)
            detectedTypes.insert(type)
        }

        // If no points selected, check handles and get their parent anchor types
        if selectedPoints.isEmpty {
            for handleID in selectedHandles {
                guard let object = snapshot.objects[handleID.shapeID],
                      case .shape(let shape) = object.objectType else {
                    continue
                }

                // Find the anchor point this handle belongs to
                let anchorElementIndex: Int
                if handleID.handleType == .control2 {
                    // control2 belongs to this element's anchor
                    anchorElementIndex = handleID.elementIndex
                } else {
                    // control1 belongs to previous element's anchor
                    // For element 1's control1, it belongs to element 0 (start point)
                    anchorElementIndex = handleID.elementIndex - 1
                }

                guard anchorElementIndex >= 0 && anchorElementIndex < shape.path.elements.count else {
                    continue
                }

                let pointID = PointID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: anchorElementIndex)
                let type = detectAnchorType(for: pointID, in: shape)
                detectedTypes.insert(type)
            }
        }

        // If all have the same type, return it
        if detectedTypes.count == 1, let type = detectedTypes.first {
            return type
        }

        // Mixed types - return auto
        return .auto
    }

    private func detectAnchorType(for pointID: PointID, in shape: VectorShape) -> AnchorPointType {
        guard pointID.elementIndex < shape.path.elements.count else {
            return .auto
        }

        let elements = shape.path.elements

        // Check if this is a closed path endpoint (element 0 or last element)
        if let closedType = detectClosedPathEndpointType(pointID: pointID, elements: elements) {
            return closedType
        }

        let element = elements[pointID.elementIndex]

        // Check incoming handle (control2 from this element)
        var incomingControl: CGPoint?
        var anchorPoint: CGPoint?

        switch element {
        case .curve(let to, _, let control2):
            let anchor = CGPoint(x: to.x, y: to.y)
            let control = CGPoint(x: control2.x, y: control2.y)
            let dist = sqrt(pow(anchor.x - control.x, 2) + pow(anchor.y - control.y, 2))
            if dist > 0.5 {
                incomingControl = control
            }
            anchorPoint = anchor
        case .move(let to), .line(let to):
            anchorPoint = CGPoint(x: to.x, y: to.y)
        default:
            break
        }

        // Check outgoing handle (control1 from next element)
        var outgoingControl: CGPoint?

        if pointID.elementIndex + 1 < elements.count {
            if case .curve(_, let control1, _) = elements[pointID.elementIndex + 1] {
                if let anchor = anchorPoint {
                    let control = CGPoint(x: control1.x, y: control1.y)
                    let dist = sqrt(pow(anchor.x - control.x, 2) + pow(anchor.y - control.y, 2))
                    if dist > 0.5 {
                        outgoingControl = control
                    }
                }
            }
        }

        // Determine type based on handles
        guard let anchor = anchorPoint else { return .auto }

        // Corner: no visible handles
        if incomingControl == nil && outgoingControl == nil {
            return .corner
        }

        // Smooth or Cusp: both handles visible
        if let incoming = incomingControl, let outgoing = outgoingControl {
            // Use dot product method (same as existing app logic)
            let vec1 = CGPoint(x: incoming.x - anchor.x, y: incoming.y - anchor.y)
            let vec2 = CGPoint(x: outgoing.x - anchor.x, y: outgoing.y - anchor.y)

            let len1 = sqrt(vec1.x * vec1.x + vec1.y * vec1.y)
            let len2 = sqrt(vec2.x * vec2.x + vec2.y * vec2.y)

            if len1 < 0.1 || len2 < 0.1 { return .corner }

            let norm1 = CGPoint(x: vec1.x / len1, y: vec1.y / len1)
            let norm2 = CGPoint(x: vec2.x / len2, y: vec2.y / len2)

            let dot = norm1.x * norm2.x + norm1.y * norm2.y

            // Smooth only if very close to 180° (within 1 degree)
            return dot < -0.9998 ? .smooth : .cusp
        }

        // One handle only = cusp
        return .cusp
    }

    private func detectClosedPathEndpointType(pointID: PointID, elements: [PathElement]) -> AnchorPointType? {
        guard elements.count >= 2 else { return nil }

        // Get first and last element indices
        var lastElementIndex = elements.count - 1
        if case .close = elements[lastElementIndex] {
            lastElementIndex -= 1
        }

        // Only check if this is element 0 or the last element
        guard pointID.elementIndex == 0 || pointID.elementIndex == lastElementIndex else {
            return nil
        }

        // Get first and last points
        guard case .move(let firstTo) = elements[0] else { return nil }
        let firstPoint = CGPoint(x: firstTo.x, y: firstTo.y)

        let lastPoint: CGPoint
        switch elements[lastElementIndex] {
        case .curve(let lastTo, _, _), .line(let lastTo), .quadCurve(let lastTo, _):
            lastPoint = CGPoint(x: lastTo.x, y: lastTo.y)
        default:
            return nil
        }

        // Check if first and last are coincident
        guard abs(firstPoint.x - lastPoint.x) < 0.1 && abs(firstPoint.y - lastPoint.y) < 0.1 else {
            return nil
        }

        // Get both handles
        var handle1: CGPoint?
        var handle2: CGPoint?

        if case .curve(_, let firstControl1, _) = elements[1] {
            handle1 = CGPoint(x: firstControl1.x, y: firstControl1.y)
        }

        if case .curve(_, _, let lastControl2) = elements[lastElementIndex] {
            handle2 = CGPoint(x: lastControl2.x, y: lastControl2.y)
        }

        // Both handles missing = corner
        guard let h1 = handle1, let h2 = handle2 else {
            return .corner
        }

        // Check if handles are collapsed
        let dist1 = sqrt(pow(h1.x - firstPoint.x, 2) + pow(h1.y - firstPoint.y, 2))
        let dist2 = sqrt(pow(h2.x - firstPoint.x, 2) + pow(h2.y - firstPoint.y, 2))

        if dist1 < 0.5 && dist2 < 0.5 {
            return .corner
        }

        if dist1 < 0.1 || dist2 < 0.1 {
            return .cusp
        }

        // Calculate vectors from anchor to handles
        let vec1 = CGPoint(x: h1.x - firstPoint.x, y: h1.y - firstPoint.y)
        let vec2 = CGPoint(x: h2.x - firstPoint.x, y: h2.y - firstPoint.y)

        let len1 = sqrt(vec1.x * vec1.x + vec1.y * vec1.y)
        let len2 = sqrt(vec2.x * vec2.x + vec2.y * vec2.y)

        let norm1 = CGPoint(x: vec1.x / len1, y: vec1.y / len1)
        let norm2 = CGPoint(x: vec2.x / len2, y: vec2.y / len2)

        let dot = norm1.x * norm2.x + norm1.y * norm2.y

        // Smooth only if very close to 180° (within 1 degree)
        return dot < -0.9998 ? .smooth : .cusp
    }

    private var prototypeAnchorTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anchor Point Type")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Button("Auto") {
                    applyAnchorTypeToSelection(.auto)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(currentAnchorType == .auto ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(currentAnchorType == .auto ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())

                Button("Corner") {
                    applyAnchorTypeToSelection(.corner)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(currentAnchorType == .corner ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(currentAnchorType == .corner ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())

                Button("Cusp") {
                    applyAnchorTypeToSelection(.cusp)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(currentAnchorType == .cusp ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(currentAnchorType == .cusp ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())

                Button("Smooth") {
                    applyAnchorTypeToSelection(.smooth)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(currentAnchorType == .smooth ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(currentAnchorType == .smooth ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    private func applyAnchorTypeToSelection(_ type: AnchorPointType) {
        print("🟢 applyAnchorTypeToSelection: Called with type \(type)")
        print("🟢 selectedPoints count: \(selectedPoints.count)")
        print("🟢 selectedPoints: \(selectedPoints)")

        guard !selectedPoints.isEmpty else {
            print("❌ No points selected - returning early")
            return
        }

        var layersToUpdate = Set<Int>()

        for pointID in selectedPoints {
            print("🔹 Processing pointID: \(pointID)")

            guard var object = snapshot.objects[pointID.shapeID],
                  case .shape(var shape) = object.objectType,
                  pointID.elementIndex < shape.path.elements.count else {
                print("❌ Failed to get object/shape or elementIndex out of bounds")
                continue
            }

            print("🔹 Shape ID: \(shape.id), geometricType: \(shape.geometricType?.rawValue ?? "nil"), isRoundedRectangle: \(shape.isRoundedRectangle)")

            let elementIndex = pointID.elementIndex
            var elements = shape.path.elements

            print("🔹 Element \(elementIndex): \(elements[elementIndex])")

            // Get anchor position
            guard let anchorPosCG = getAnchorPosition(from: elements[elementIndex]) else { continue }
            let anchorPos = VectorPoint(anchorPosCG.x, anchorPosCG.y)

            // Convert line element to curve if needed (for rectangles/polygons)
            // Only convert THIS element, not neighbors
            if case .line = elements[elementIndex] {
                print("🔶 Converting LINE element to CURVE element at index \(elementIndex)")
                elements[elementIndex] = .curve(to: anchorPos, control1: anchorPos, control2: anchorPos)
            }

            // Modify the element and next element based on type
            switch type {
            case .corner:
                // Collapse handles to anchor (corner = no visible handles)
                // Collapse incoming handle (control2 of current element)
                if case .curve(_, let control1, _) = elements[elementIndex] {
                    elements[elementIndex] = .curve(to: anchorPos, control1: control1, control2: anchorPos)
                }
                // Collapse outgoing handle (control1 of next element)
                if elementIndex + 1 < elements.count {
                    if case .curve(let to, _, let control2) = elements[elementIndex + 1] {
                        elements[elementIndex + 1] = .curve(to: to, control1: anchorPos, control2: control2)
                    }
                }

            case .cusp:
                // Create handles at 90° angle from each other
                let handleLength: Double = 40.0

                // Get existing handle direction or use defaults
                var incomingAngle: Double = .pi * 1.25  // 225° default
                var outgoingAngle: Double = .pi * 0.25  // 45° default (90° from incoming)

                // If incoming handle exists, use its angle
                if case .curve(_, _, let control2) = elements[elementIndex] {
                    let dx = anchorPos.x - control2.x
                    let dy = anchorPos.y - control2.y
                    let dist = sqrt(dx * dx + dy * dy)
                    if dist > 0.5 {
                        incomingAngle = atan2(dy, dx)
                    }
                }

                // Calculate outgoing at 90° from incoming
                outgoingAngle = incomingAngle + .pi / 2

                // Create new control points
                let newControl2 = VectorPoint(
                    anchorPos.x - cos(incomingAngle) * handleLength,
                    anchorPos.y - sin(incomingAngle) * handleLength
                )

                let newControl1 = VectorPoint(
                    anchorPos.x + cos(outgoingAngle) * handleLength,
                    anchorPos.y + sin(outgoingAngle) * handleLength
                )

                // Update incoming handle
                if case .curve(_, let oldControl1, _) = elements[elementIndex] {
                    elements[elementIndex] = .curve(to: anchorPos, control1: oldControl1, control2: newControl2)
                }

                // Update outgoing handle
                if elementIndex + 1 < elements.count {
                    // Convert next element to curve if it's a line
                    if case .line(let to) = elements[elementIndex + 1] {
                        print("🔶 Converting NEXT LINE to CURVE for cusp outgoing handle")
                        let toPoint = VectorPoint(to.x, to.y)
                        elements[elementIndex + 1] = .curve(to: toPoint, control1: newControl1, control2: toPoint)
                    } else if case .curve(let to, _, let oldControl2) = elements[elementIndex + 1] {
                        elements[elementIndex + 1] = .curve(to: to, control1: newControl1, control2: oldControl2)
                    }
                }

            case .smooth:
                // Make handles collinear (180° aligned through anchor)
                var incomingHandle: CGPoint?
                var outgoingHandle: CGPoint?

                // Get incoming handle (control2 from this element)
                if case .curve(_, _, let control2) = elements[elementIndex] {
                    incomingHandle = CGPoint(x: control2.x, y: control2.y)
                }

                // Get outgoing handle (control1 from next element)
                if elementIndex + 1 < elements.count {
                    if case .curve(_, let control1, _) = elements[elementIndex + 1] {
                        outgoingHandle = CGPoint(x: control1.x, y: control1.y)
                    } else if case .line(let to) = elements[elementIndex + 1] {
                        // Next is line, create handle at anchor position
                        outgoingHandle = anchorPosCG
                    }
                }

                // If both handles exist, align them
                if let incoming = incomingHandle, let outgoing = outgoingHandle {
                    // Calculate vectors from anchor to each handle
                    let inVec = CGPoint(x: incoming.x - anchorPosCG.x, y: incoming.y - anchorPosCG.y)
                    let outVec = CGPoint(x: outgoing.x - anchorPosCG.x, y: outgoing.y - anchorPosCG.y)

                    let inLen = sqrt(inVec.x * inVec.x + inVec.y * inVec.y)
                    let outLen = sqrt(outVec.x * outVec.x + outVec.y * outVec.y)

                    // Use the longer handle to determine the direction
                    let useIncoming = inLen > outLen

                    if useIncoming && inLen > 0.1 {
                        // Align outgoing to be opposite of incoming
                        let norm = CGPoint(x: inVec.x / inLen, y: inVec.y / inLen)
                        let newControl1 = VectorPoint(
                            anchorPosCG.x - norm.x * outLen,
                            anchorPosCG.y - norm.y * outLen
                        )
                        // Convert next element to curve if it's a line
                        if case .line(let to) = elements[elementIndex + 1] {
                            print("🔶 Converting NEXT LINE to CURVE for smooth outgoing handle")
                            let toPoint = VectorPoint(to.x, to.y)
                            elements[elementIndex + 1] = .curve(to: toPoint, control1: newControl1, control2: toPoint)
                        } else if case .curve(let to, _, let control2) = elements[elementIndex + 1] {
                            elements[elementIndex + 1] = .curve(to: to, control1: newControl1, control2: control2)
                        }
                    } else if outLen > 0.1 {
                        // Align incoming to be opposite of outgoing
                        let norm = CGPoint(x: outVec.x / outLen, y: outVec.y / outLen)
                        let newControl2 = VectorPoint(
                            anchorPosCG.x - norm.x * inLen,
                            anchorPosCG.y - norm.y * inLen
                        )
                        if case .curve(_, let control1, _) = elements[elementIndex] {
                            elements[elementIndex] = .curve(to: anchorPos, control1: control1, control2: newControl2)
                        }
                    }
                }

            case .auto:
                // Auto mode - remove stored type to use geometry detection
                shape.anchorTypes.removeValue(forKey: elementIndex)
            }

            // Store the explicit anchor type (except for .auto which uses geometry)
            if type != .auto {
                shape.anchorTypes[elementIndex] = type
                print("✅ StrokeFillPanel: Stored anchor type \(type) for element \(elementIndex) in shape \(pointID.shapeID)")
            } else {
                print("🔷 StrokeFillPanel: Removed stored anchor type for element \(elementIndex) (set to AUTO)")
            }

            // Log all stored anchor types for this shape
            print("📋 StrokeFillPanel: All anchor types for shape: \(shape.anchorTypes)")

            // Update the shape
            shape.path = VectorPath(elements: elements)
            shape.updateBounds()
            object = VectorObject(shape: shape, layerIndex: object.layerIndex)
            snapshot.objects[pointID.shapeID] = object
            layersToUpdate.insert(object.layerIndex)
        }

        // Trigger updates for affected layers
        if !layersToUpdate.isEmpty {
            onTriggerLayerUpdates(layersToUpdate)
        }
    }

    private func getAnchorPosition(from element: PathElement) -> CGPoint? {
        switch element {
        case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
            return CGPoint(x: to.x, y: to.y)
        case .close:
            return nil
        }
    }

    private func distance(from p1: CGPoint, to p2: VectorPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }

    private func normalize(from p1: VectorPoint, to p2: CGPoint) -> CGPoint {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0.001 else { return CGPoint(x: 1, y: 0) }
        return CGPoint(x: dx / len, y: dy / len)
    }

    private var selectedStrokeColor: VectorColor {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.hasStroke == true ? shape.typography?.strokeColor ?? .clear : .clear
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let strokeColor = shape.strokeStyle?.color {
                    return strokeColor
                } else {
                    return .clear
                }
            }
        }
        return defaultStrokeColor
    }

    private var selectedFillColor: VectorColor {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.fillColor ?? .black
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let fillStyle = shape.fillStyle {
                    return fillStyle.color
                }
            }
        }
        return defaultFillColor
    }

    private var strokeWidth: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.strokeWidth ?? defaultStrokeWidth
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.width ?? defaultStrokeWidth
            }
        }
        return defaultStrokeWidth
    }

    private var strokePlacement: StrokePlacement {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return strokeDefaults.placement
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.placement ?? strokeDefaults.placement
            }
        }
        return strokeDefaults.placement
    }

    private var fillOpacity: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.fillOpacity ?? defaultFillOpacity
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let opacity = shape.fillStyle?.opacity {
                    return opacity
                }
            }
        }
        return defaultFillOpacity
    }

    private var strokeOpacity: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.strokeOpacity ?? defaultStrokeOpacity
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let opacity = shape.strokeStyle?.opacity {
                    return opacity
                }
            }
        }
        return defaultStrokeOpacity
    }

    private var strokeLineJoin: CGLineJoin {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return strokeDefaults.lineJoin
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.lineJoin.cgLineJoin ?? strokeDefaults.lineJoin
            }
        }
        return strokeDefaults.lineJoin
    }

    private var strokeLineCap: CGLineCap {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return strokeDefaults.lineCap
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.lineCap.cgLineCap ?? strokeDefaults.lineCap
            }
        }
        return strokeDefaults.lineCap
    }

    private var strokeMiterLimit: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return strokeDefaults.miterLimit
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.miterLimit ?? strokeDefaults.miterLimit
            }
        }
        return strokeDefaults.miterLimit
    }

    private var strokeScaleWithTransform: Bool {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return false
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.scaleWithTransform ?? false
            }
        }
        return false
    }

    private var hasSelectedImages: Bool {
        return selectedObjectIDs.contains { objectID in
            if let newVectorObject = snapshot.objects[objectID] {
                switch newVectorObject.objectType {
                case .text:
                    return false
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    return shape.linkedImagePath != nil || shape.embeddedImageData != nil
                }
            }
            return false
        }
    }

    private var selectedImageOpacity: Double {
        for objectID in selectedObjectIDs {
            if let newVectorObject = snapshot.objects[objectID] {
                switch newVectorObject.objectType {
                case .text:
                    continue
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    if shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                        return shape.opacity
                    }
                }
            }
        }
        return 1.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                    CurrentColorsView(
                        strokeColor: selectedStrokeColor,
                        fillColor: selectedFillColor,
                        strokeOpacity: strokeOpacityState,
                        fillOpacity: fillOpacityState,
                        snapshot: $snapshot,
                        selectedObjectIDs: selectedObjectIDs,
                        activeColorTarget: activeColorTarget,
                        colorMode: $colorMode,
                        defaultFillColor: $defaultFillColor,
                        defaultStrokeColor: $defaultStrokeColor,
                        defaultFillOpacity: defaultFillOpacity,
                        defaultStrokeOpacity: defaultStrokeOpacity,
                        currentSwatches: currentSwatches,
                        onTriggerLayerUpdates: onTriggerLayerUpdates,
                        onAddColorSwatch: onAddColorSwatch,
                        onRemoveColorSwatch: onRemoveColorSwatch,
                        onSetActiveColor: onSetActiveColor,
                        colorDeltaColor: $colorDeltaColor,
                        colorDeltaOpacity: $colorDeltaOpacity,
                        onSetActiveColorTarget: onSetActiveColorTarget,
                        onColorSelected: onSetActiveColor
                    )

                    // PROTOTYPE: Anchor Point Type Selector
                    prototypeAnchorTypeSelector

                    FillPropertiesSection(
                        fillOpacity: fillOpacityState,
                        fillColor: selectedFillColor,
                        onApplyFill: applyFillToSelectedShapes,
                        onUpdateFillOpacity: { value in
                            fillOpacityState = value
                            colorDeltaOpacity = value
                            updateFillOpacityLive(value, isEditing: true)
                        },
                        onFillOpacityEditingChanged: { isEditing in
                            if isEditing {
                                colorDeltaOpacity = fillOpacityState
                            } else {
                                colorDeltaOpacity = nil
                                defaultFillOpacity = fillOpacityState
                                for objectID in selectedObjectIDs {
                                    onUpdateObjectOpacity(objectID, fillOpacityState, .fill)
                                }
                            }
                        }
                    )

                    if hasSelectedImages {
                        ImagePropertiesSection(
                            imageOpacity: selectedImageOpacityState,
                            onUpdateImageOpacity: { value in
                                selectedImageOpacityState = value
                                updateImageOpacity(value)
                            }
                        )
                    }

                    StrokePropertiesSection(
                        strokeWidth: strokeWidthState,
                        strokePlacement: strokePlacementState,
                        strokeOpacity: strokeOpacityState,
                        strokeColor: selectedStrokeColor,
                        strokeLineJoin: strokeLineJoin,
                        strokeLineCap: strokeLineCap,
                        strokeMiterLimit: strokeMiterLimitState,
                        strokeScaleWithTransform: strokeScaleWithTransform,
                        onUpdateStrokeWidth: { value in
                            strokeWidthState = value
                            strokeDeltaWidth = value
                            updateStrokeWidthLive(value, isEditing: true)
                        },
                        onUpdateStrokeOpacity: { value in
                            strokeOpacityState = value
                            colorDeltaOpacity = value
                            updateStrokeOpacityLive(value, isEditing: true)
                        },
                        onUpdateStrokePlacement: { value in
                            strokePlacementState = value
                            updateStrokePlacement(value)
                        },
                        onUpdateLineJoin: { value in
                            var updatedDefaults = strokeDefaults
                            updatedDefaults.lineJoin = value
                            onUpdateStrokeDefaults(updatedDefaults)
                            updateStrokeLineJoin(value)
                        },
                        onUpdateLineCap: { value in
                            var updatedDefaults = strokeDefaults
                            updatedDefaults.lineCap = value
                            onUpdateStrokeDefaults(updatedDefaults)
                            updateStrokeLineCap(value)
                        },
                        onUpdateMiterLimit: { value in
                            strokeMiterLimitState = value
                            updateStrokeMiterLimitDirectNoUndo(value)
                        },
                        onUpdateScaleWithTransform: { value in
                            updateStrokeScaleWithTransform(value)
                        },
                        onStrokeWidthEditingChanged: { isEditing in
                            if isEditing {
                                strokeDeltaWidth = strokeWidthState
                            } else {
                                strokeDeltaWidth = nil
                                defaultStrokeWidth = strokeWidthState
                                for objectID in selectedObjectIDs {
                                    onUpdateObjectStrokeWidth(objectID, strokeWidthState)
                                }
                            }
                        },
                        onStrokeOpacityEditingChanged: { isEditing in
                            if isEditing {
                                colorDeltaOpacity = strokeOpacityState
                            } else {
                                colorDeltaOpacity = nil
                                defaultStrokeOpacity = strokeOpacityState
                                for objectID in selectedObjectIDs {
                                    onUpdateObjectOpacity(objectID, strokeOpacityState, .stroke)
                                }
                            }
                        },
                        onMiterLimitEditingChanged: { isEditing in
                            if !isEditing {
                                updateStrokeMiterLimit(strokeMiterLimitState)
                            }
                        }
                    )

                    HStack(spacing: 8) {
                        Button {
                            onOutlineSelectedStrokes()
                        } label: {
                            Text("Expand Stroke")
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
                            onOutlineSelectedStrokes()
                        }
                        .help("Convert stroke to filled path (Cmd+Shift+O)")
                        .keyboardShortcut("o", modifiers: [.command, .shift])

                        Button {
                            onDuplicateSelectedShapes()
                        } label: {
                            Text("Duplicate")
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
                            onDuplicateSelectedShapes()
                        }
                        .help("Duplicate selected shapes (Cmd+D)")
                        .keyboardShortcut("d", modifiers: .command)
                    }
                    .padding(.horizontal, 12)

                    switch currentTool {
                    case .freehand:
                        FreehandSettingsSection()
                    case .brush:
                        VariableStrokeSection(hasPressureInput: hasPressureInput)
                    case .marker:
                        MarkerSettingsSection()
                    default:
                        EmptyView()
                    }

                    TransformPreferencesSection()

                Spacer()
            }
            .padding()
        }
        .onAppear {
            syncOpacityStates()
        }
        .onChange(of: selectedObjectIDs) { _, _ in
            syncOpacityStates()
        }
        .onChange(of: changeToken) { _, _ in
            if !isDragging {
                syncOpacityStates()
            }
        }
    }

    private func syncOpacityStates() {
        fillOpacityState = fillOpacity
        strokeOpacityState = strokeOpacity
        strokeWidthState = strokeWidth
        strokePlacementState = strokePlacement
        strokeMiterLimitState = strokeMiterLimit
        selectedImageOpacityState = selectedImageOpacity
    }

    private func updateFillOpacityLive(_ opacity: Double, isEditing: Bool) {
        onUpdateFillOpacityLive(opacity, isEditing)
    }

    private func updateStrokeOpacityLive(_ opacity: Double, isEditing: Bool) {
        onUpdateStrokeOpacityLive(opacity, isEditing)
    }

    private func updateStrokeWidthLive(_ width: Double, isEditing: Bool) {
        onUpdateStrokeWidthLive(width, isEditing)
    }

    private func updateStrokePlacementLive(_ placement: StrokePlacement) {
        var updatedDefaults = strokeDefaults
        updatedDefaults.placement = placement
        onUpdateStrokeDefaults(updatedDefaults)

        for objectID in selectedObjectIDs {
            if let newVectorObject = snapshot.objects[objectID] {
                switch newVectorObject.objectType {
                case .text:
                    break
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    onUpdateShapeStrokePlacementInUnified(shape.id, placement)
                }
            }
        }
    }

    private func updateStrokePlacement(_ placement: StrokePlacement) {
        onUpdateStrokePlacement(placement)
    }

    private func updateStrokeLineJoin(_ lineJoin: CGLineJoin) {
        onUpdateStrokeLineJoin(lineJoin)
    }

    private func updateStrokeLineCap(_ lineCap: CGLineCap) {
        onUpdateStrokeLineCap(lineCap)
    }

    private func updateStrokeMiterLimit(_ miterLimit: Double) {
        onUpdateStrokeMiterLimit(miterLimit)
    }

    private func updateStrokeMiterLimitDirectNoUndo(_ miterLimit: Double) {
        onUpdateStrokeMiterLimitDirectNoUndo(miterLimit)
    }

    private func updateStrokeScaleWithTransform(_ scaleWithTransform: Bool) {
        onUpdateStrokeScaleWithTransform(scaleWithTransform)
    }

    private func updateImageOpacity(_ opacity: Double) {
        onUpdateImageOpacity(opacity)
    }

    private func applyFillToSelectedShapes() {
        onApplyFillToSelectedShapes(selectedFillColor, fillOpacity)
    }

}
