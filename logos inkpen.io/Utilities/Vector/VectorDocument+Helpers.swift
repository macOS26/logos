import SwiftUI
import Combine

extension VectorDocument {

    var rgbSwatches: [VectorColor] {
        var swatches = ColorManager.shared.colorDefaults.rgbSwatches
        swatches.append(contentsOf: customRgbSwatches)
        return swatches
    }

    var cmykSwatches: [VectorColor] {
        var swatches = ColorManager.shared.colorDefaults.cmykSwatches
        swatches.append(contentsOf: customCmykSwatches)
        return swatches
    }

    var hsbSwatches: [VectorColor] {
        var swatches = ColorManager.shared.colorDefaults.hsbSwatches
        swatches.append(contentsOf: customHsbSwatches)
        return swatches
    }

    var allShapes: [VectorShape] {
        return unifiedObjects.compactMap { unifiedObject in
            switch unifiedObject.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape
            case .text:
                return nil
            }
        }
    }

    var allObjectsByLayer: [Int: [VectorObject]] {
        return Dictionary(grouping: unifiedObjects) { $0.layerIndex }
    }

    var defaultFillColor: VectorColor {
        get { documentColorDefaults.fillColor }
        set {
            objectWillChange.send()
            documentColorDefaults.fillColor = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }

    var defaultStrokeColor: VectorColor {
        get { documentColorDefaults.strokeColor }
        set {
            objectWillChange.send()
            documentColorDefaults.strokeColor = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }

    var defaultFillOpacity: Double {
        get { documentColorDefaults.fillOpacity }
        set {
            documentColorDefaults.fillOpacity = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }

    var defaultStrokeOpacity: Double {
        get { documentColorDefaults.strokeOpacity }
        set {
            documentColorDefaults.strokeOpacity = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }

    var defaultStrokeWidth: Double {
        get { documentColorDefaults.strokeWidth }
        set {
            documentColorDefaults.strokeWidth = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }

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
                case .group(let shape):
                    let shapeBounds = shape.groupBounds
                    if let existing = combinedBounds {
                        combinedBounds = existing.union(shapeBounds)
                    } else {
                        combinedBounds = shapeBounds
                    }
                case .shape(let shape),
                     .text(let shape),
                     .warp(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    let shapeBounds = shape.bounds
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
            switch object.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                allShapeIDs.insert(shape.id)
            case .group(let shape):
                allShapeIDs.insert(shape.id)
                if shape.isGroupContainer {
                    for groupedShape in shape.groupedShapes {
                        allShapeIDs.insert(groupedShape.id)
                    }
                }
            case .text:
                break
            }
        }

        ImageContentRegistry.cleanup(keepingShapes: allShapeIDs)
    }

    func collectUsedColors() -> Set<VectorColor> {
        var colors = Set<VectorColor>()

        for object in unifiedObjects {
            switch object.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let fillStyle = shape.fillStyle {
                    colors.insert(fillStyle.color)
                }

                if let strokeStyle = shape.strokeStyle {
                    colors.insert(strokeStyle.color)
                }
            case .text(let shape):
                if let fillColor = shape.typography?.fillColor {
                    colors.insert(fillColor)
                }
                if let strokeColor = shape.typography?.strokeColor {
                    colors.insert(strokeColor)
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

    func rebuildIndexCache() {
        unifiedObjectIndexCache = Dictionary(uniqueKeysWithValues: unifiedObjects.enumerated().map { ($0.element.id, $0.offset) })
        rebuildLayerCache()
    }

    func rebuildLayerCache() {
        objectsByLayerCache = Dictionary(grouping: unifiedObjects, by: { $0.layerIndex })
    }

    func findObject(by id: UUID) -> VectorObject? {
        guard let index = unifiedObjectIndexCache[id], index < unifiedObjects.count else {
            return nil
        }
        return unifiedObjects[index]
    }

    func findObjectIndex(by id: UUID) -> Int? {
        return unifiedObjectIndexCache[id]
    }

    func findShape(by id: UUID) -> VectorShape? {
        guard let index = unifiedObjectIndexCache[id], index < unifiedObjects.count else {
            return nil
        }
        let object = unifiedObjects[index]
        switch object.objectType {
        case .shape(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
            return shape
        case .text:
            return nil
        }
    }

    func findText(by id: UUID) -> VectorText? {
        // First check if it's a top-level text object in unifiedObjects
        if let index = unifiedObjectIndexCache[id], index < unifiedObjects.count {
            let object = unifiedObjects[index]
            if case .text(let shape) = object.objectType,
               var vectorText = VectorText.from(shape) {
                vectorText.layerIndex = object.layerIndex
                return vectorText
            }
        }

        // Not in cache or not a text object - search inside groups
        for object in unifiedObjects {
            if case .group(let shape) = object.objectType {
                if let textShape = shape.groupedShapes.first(where: { $0.id == id && $0.typography != nil }),
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
        // Array position IS the order now - no sorting needed
        for unifiedObject in unifiedObjects {
            if case .text(let shape) = unifiedObject.objectType,
               let text = VectorText.from(shape) {
                try action(text)
            }
        }
    }

    func getShapesInLayer(_ layerIndex: Int) -> [VectorShape] {
        return allShapes.filter { shape in
            return unifiedObjects.first { obj in
                switch obj.objectType {
                case .shape(let objShape),
                     .warp(let objShape),
                     .group(let objShape),
                     .clipGroup(let objShape),
                     .clipMask(let objShape):
                    return objShape.id == shape.id && obj.layerIndex == layerIndex
                case .text:
                    return false
                }
            } != nil
        }
    }
}
