import SwiftUI

extension VectorDocument {

    func syncEncodableStorage() {
        _encodableSettings = settings
        _encodableLayers = layers
        _encodableCurrentTool = currentTool
        _encodableViewMode = viewMode
        _encodableZoomLevel = zoomLevel
        _encodableCanvasOffset = canvasOffset
        _encodableUnifiedObjects = unifiedObjects
    }

    var currentSwatches: [VectorColor] {
        switch settings.colorMode {
        case .rgb:
            return rgbSwatches
        case .cmyk:
            return cmykSwatches
        case .pms:
            return hsbSwatches
        }
    }

    func addCustomSwatch(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            if !customRgbSwatches.contains(where: { $0 == color }) {
                customRgbSwatches.append(color)
            }
        case .cmyk:
            if !customCmykSwatches.contains(where: { $0 == color }) {
                customCmykSwatches.append(color)
            }
        case .pms:
            if !customHsbSwatches.contains(where: { $0 == color }) {
                customHsbSwatches.append(color)
            }
        }
    }

    func removeCustomSwatch(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            customRgbSwatches.removeAll(where: { $0 == color })
        case .cmyk:
            customCmykSwatches.removeAll(where: { $0 == color })
        case .pms:
            customHsbSwatches.removeAll(where: { $0 == color })
        }
    }

    func updateTransformPanelValues() {
        guard !selectedObjectIDs.isEmpty else { return }

        var combinedBounds: CGRect?
        for objectID in selectedObjectIDs {
            if let unifiedObject = findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    let shapeBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                    if let existing = combinedBounds {
                        combinedBounds = existing.union(shapeBounds)
                    } else {
                        combinedBounds = shapeBounds
                    }
                }
            }
        }

        objectPositionUpdateTrigger.toggle()
    }

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

    func rebuildLookupCache() {
        unifiedObjectLookupCache = Dictionary(uniqueKeysWithValues: unifiedObjects.map { ($0.id, $0) })
        rebuildLayerCache()
    }

    func rebuildLayerCache() {
        objectsByLayerCache = Dictionary(grouping: unifiedObjects, by: { $0.layerIndex })
    }

    func findObject(by id: UUID) -> VectorObject? {
        return unifiedObjectLookupCache[id]
    }

    func findObjectIndex(by id: UUID) -> Int? {
        return unifiedObjects.firstIndex(where: { $0.id == id })
    }

    func findShape(by id: UUID) -> VectorShape? {
        guard let object = unifiedObjectLookupCache[id],
              case .shape(let shape) = object.objectType,
              !shape.isTextObject else { return nil }
        return shape
    }

    func findText(by id: UUID) -> VectorText? {
        if let object = unifiedObjectLookupCache[id],
           case .shape(let shape) = object.objectType,
           shape.isTextObject,
           var vectorText = VectorText.from(shape) {
            vectorText.layerIndex = object.layerIndex
            return vectorText
        }

        for object in unifiedObjects {
            if case .shape(let shape) = object.objectType, shape.isGroupContainer {
                if let textShape = shape.groupedShapes.first(where: { $0.id == id && $0.isTextObject }),
                   var vectorText = VectorText.from(textShape) {
                    vectorText.layerIndex = object.layerIndex
                    return vectorText
                }
            }
        }

        return nil
    }

    func getObjectsInLayer(_ layerIndex: Int) -> [VectorObject] {
        return objectsByLayerCache[layerIndex] ?? []
    }

    func forEachTextInOrder(_ action: (VectorText) throws -> Void) rethrows {
        for unifiedObject in unifiedObjects.sorted(by: { $0.orderID < $1.orderID }) {
            if case .shape(let shape) = unifiedObject.objectType, shape.isTextObject,
               let text = VectorText.from(shape) {
                try action(text)
            }
        }
    }

    func getShapesInLayer(_ layerIndex: Int) -> [VectorShape] {
        return allShapes.filter { shape in
            return unifiedObjects.first { obj in
                if case .shape(let objShape) = obj.objectType {
                    return objShape.id == shape.id && obj.layerIndex == layerIndex
                }
                return false
            } != nil
        }
    }
}
