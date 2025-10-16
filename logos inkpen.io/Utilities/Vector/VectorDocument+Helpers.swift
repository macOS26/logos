import SwiftUI

extension VectorDocument {

    func cleanupImageRegistry() {
        var allShapeIDs = Set<UUID>()

        for object in unifiedObjects {
            if case .shape(let shape) = object.objectType {
                allShapeIDs.insert(shape.id)
                if shape.isGroupContainer {
                    for groupedShape in shape.groupedShapes {
                        allShapeIDs.insert(groupedShape.id)
                    }
                }
            }
        }

        ImageContentRegistry.cleanup(keepingShapes: allShapeIDs)
    }

    func collectUsedColors() -> Set<VectorColor> {
        var colors = Set<VectorColor>()

        for object in unifiedObjects {
            if case .shape(let shape) = object.objectType {
                if let fillStyle = shape.fillStyle {
                    colors.insert(fillStyle.color)
                }

                if let strokeStyle = shape.strokeStyle {
                    colors.insert(strokeStyle.color)
                }
            }
        }

        if backgroundColor != .white {
            colors.insert(backgroundColor)
        }

        return colors
    }

    static func isPermanentColor(_ color: VectorColor) -> Bool {
        switch color {
        case .black, .white, .clear:
            return true
        default:
            return false
        }
    }

    func applyScalingToShape(
        shapeId: UUID,
        scaleX: CGFloat,
        scaleY: CGFloat,
        initialTransform: CGAffineTransform,
        initialBounds: CGRect
    ) {
        for layerIndex in layers.indices {
            let shapes = getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeId }) {
                let centerX = initialBounds.midX
                let centerY = initialBounds.midY
                let scaleTransform = CGAffineTransform.identity
                    .translatedBy(x: centerX, y: centerY)
                    .scaledBy(x: scaleX, y: scaleY)
                    .translatedBy(x: -centerX, y: -centerY)

                let newTransform = initialTransform.concatenating(scaleTransform)

                guard var shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                shape.transform = newTransform
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)

                applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
                break
            }
        }
    }

    func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int) {
        guard var shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let transform = shape.transform

        if transform.isIdentity {
            return
        }

        shape.path = shape.path.applying(transform)
        shape.transform = .identity
        shape.updateBounds()
        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
    }

    func saveStrokeStyleDefaults() {
        var prefs: [String: Any] = [:]
        prefs["strokePlace"] = defaultStrokePlacement.rawValue
        prefs["strokeJoin"] = Int(defaultStrokeLineJoin.rawValue)
        prefs["strokeCap"] = Int(defaultStrokeLineCap.rawValue)
        prefs["strokeMiter"] = defaultStrokeMiterLimit
        UserDefaults.standard.set(prefs, forKey: "strokeStylePrefs")
    }

    func loadStrokeStyleDefaults() {
        guard let prefs = UserDefaults.standard.dictionary(forKey: "strokeStylePrefs") else { return }

        if let placement = prefs["strokePlace"] as? String {
            defaultStrokePlacement = StrokePlacement(rawValue: placement) ?? .center
        }
        if let joinInt = prefs["strokeJoin"] as? Int {
            defaultStrokeLineJoin = CGLineJoin(rawValue: Int32(joinInt)) ?? .miter
        }
        if let capInt = prefs["strokeCap"] as? Int {
            defaultStrokeLineCap = CGLineCap(rawValue: Int32(capInt)) ?? .butt
        }
        if let miter = prefs["strokeMiter"] as? Double {
            defaultStrokeMiterLimit = miter
        }
    }
}
