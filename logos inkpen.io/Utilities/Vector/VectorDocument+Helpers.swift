import SwiftUI
import Combine

extension VectorDocument {

    var rgbSwatches: [VectorColor] {
        var swatches = ColorManager.shared.colorDefaults.rgbSwatches
        swatches.append(contentsOf: colorSwatches.rgb)
        return swatches
    }

    var cmykSwatches: [VectorColor] {
        var swatches = ColorManager.shared.colorDefaults.cmykSwatches
        swatches.append(contentsOf: colorSwatches.cmyk)
        return swatches
    }

    var hsbSwatches: [VectorColor] {
        var swatches = ColorManager.shared.colorDefaults.hsbSwatches
        swatches.append(contentsOf: colorSwatches.hsb)
        return swatches
    }

    var allShapes: [VectorShape] {
        return snapshot.objects.values.compactMap { object in
            switch object.objectType {
            case .shape(let shape),
                 .image(let shape),
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

    var defaultFillColor: VectorColor {
        get { documentColorDefaults.fillColor }
        set {
            documentColorDefaults.fillColor = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }

    var defaultStrokeColor: VectorColor {
        get { documentColorDefaults.strokeColor }
        set {
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
        _encodableCurrentTool = viewState.currentTool
        _encodableViewMode = viewState.viewMode
        _encodableZoomLevel = viewState.zoomLevel
        _encodableCanvasOffset = viewState.canvasOffset
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
            if !colorSwatches.rgb.contains(where: { $0 == color }) {
                colorSwatches.rgb.append(color)
            }
        case .cmyk:
            if !colorSwatches.cmyk.contains(where: { $0 == color }) {
                colorSwatches.cmyk.append(color)
            }
        case .pms:
            if !colorSwatches.hsb.contains(where: { $0 == color }) {
                colorSwatches.hsb.append(color)
            }
        }
    }

    func removeCustomSwatch(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            colorSwatches.rgb.removeAll(where: { $0 == color })
        case .cmyk:
            colorSwatches.cmyk.removeAll(where: { $0 == color })
        case .pms:
            colorSwatches.hsb.removeAll(where: { $0 == color })
        }
    }

    func updateTransformPanelValues() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        var combinedBounds: CGRect?
        for objectID in viewState.selectedObjectIDs {
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
                     .image(let shape),
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

        viewState.objectPositionUpdateTrigger.toggle()
    }

    func cleanupImageRegistry() {
        var allShapeIDs = Set<UUID>()

        for object in snapshot.objects.values {
            switch object.objectType {
            case .shape(let shape),
                 .image(let shape),
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

        ImageContentRegistry.cleanup(keepingShapes: allShapeIDs, in: self)
    }

    func collectUsedColors() -> Set<VectorColor> {
        var colors = Set<VectorColor>()

        for object in snapshot.objects.values {
            switch object.objectType {
            case .shape(let shape),
                 .image(let shape),
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

        if settings.backgroundColor != .white {
            colors.insert(settings.backgroundColor)
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
        prefs["strokePlace"] = strokeDefaults.placement.rawValue
        prefs["strokeJoin"] = Int(strokeDefaults.lineJoin.rawValue)
        prefs["strokeCap"] = Int(strokeDefaults.lineCap.rawValue)
        prefs["strokeMiter"] = strokeDefaults.miterLimit
        UserDefaults.standard.set(prefs, forKey: "strokeStylePrefs")
    }

    func loadStrokeStyleDefaults() {
        guard let prefs = UserDefaults.standard.dictionary(forKey: "strokeStylePrefs") else { return }

        if let placement = prefs["strokePlace"] as? String {
            strokeDefaults.placement = StrokePlacement(rawValue: placement) ?? .center
        }
        if let joinInt = prefs["strokeJoin"] as? Int {
            strokeDefaults.lineJoin = CGLineJoin(rawValue: Int32(joinInt)) ?? .miter
        }
        if let capInt = prefs["strokeCap"] as? Int {
            strokeDefaults.lineCap = CGLineCap(rawValue: Int32(capInt)) ?? .butt
        }
        if let miter = prefs["strokeMiter"] as? Double {
            strokeDefaults.miterLimit = miter
        }
    }

    func findObject(by id: UUID) -> VectorObject? {
        return snapshot.objects[id]
    }

    func findShape(by id: UUID) -> VectorShape? {
        guard let object = snapshot.objects[id] else {
            return nil
        }
        switch object.objectType {
        case .shape(let shape),
             .image(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
            return shape
        case .text(let shape):
            return shape
        }
    }

    func findText(by id: UUID) -> VectorText? {
        // O(1) lookup in snapshot.objects
        if let object = snapshot.objects[id] {
            if case .text(let shape) = object.objectType,
               var vectorText = VectorText.from(shape) {
                vectorText.layerIndex = object.layerIndex
                return vectorText
            }
        }

        // Not a top-level text object - search inside groups
        for object in snapshot.objects.values {
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

    func forEachTextInOrder(_ action: (VectorText) throws -> Void) rethrows {
        // Iterate through layers to preserve order
        for layer in snapshot.layers {
            for objectID in layer.objectIDs {
                guard let object = snapshot.objects[objectID] else { continue }
                if case .text(let shape) = object.objectType,
                   let text = VectorText.from(shape) {
                    try action(text)
                }
            }
        }
    }

    func getShapesInLayer(_ layerIndex: Int) -> [VectorShape] {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return [] }

        let layer = snapshot.layers[layerIndex]
        return layer.objectIDs.compactMap { objectID in
            guard let object = snapshot.objects[objectID] else { return nil }
            switch object.objectType {
            case .shape(let shape),
                 .image(let shape),
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
}
