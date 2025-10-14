import Foundation
import Combine
import CoreGraphics

/// Command for changing stroke properties (placement, line join, line cap, miter limit)
class StrokePropertiesCommand: BaseCommand {
    enum PropertyType {
        case placement
        case lineJoin
        case lineCap
        case miterLimit
        case imageOpacity
    }

    private let objectIDs: [UUID]
    private let propertyType: PropertyType
    private let oldPlacements: [UUID: StrokePlacement]?
    private let newPlacements: [UUID: StrokePlacement]?
    private let oldLineJoins: [UUID: CGLineJoin]?
    private let newLineJoins: [UUID: CGLineJoin]?
    private let oldLineCaps: [UUID: CGLineCap]?
    private let newLineCaps: [UUID: CGLineCap]?
    private let oldMiterLimits: [UUID: Double]?
    private let newMiterLimits: [UUID: Double]?
    private let oldOpacities: [UUID: Double]?
    private let newOpacities: [UUID: Double]?

    init(objectIDs: [UUID],
         placement old: [UUID: StrokePlacement],
         new: [UUID: StrokePlacement]) {
        self.objectIDs = objectIDs
        self.propertyType = .placement
        self.oldPlacements = old
        self.newPlacements = new
        self.oldLineJoins = nil
        self.newLineJoins = nil
        self.oldLineCaps = nil
        self.newLineCaps = nil
        self.oldMiterLimits = nil
        self.newMiterLimits = nil
        self.oldOpacities = nil
        self.newOpacities = nil
    }

    init(objectIDs: [UUID],
         lineJoin old: [UUID: CGLineJoin],
         new: [UUID: CGLineJoin]) {
        self.objectIDs = objectIDs
        self.propertyType = .lineJoin
        self.oldPlacements = nil
        self.newPlacements = nil
        self.oldLineJoins = old
        self.newLineJoins = new
        self.oldLineCaps = nil
        self.newLineCaps = nil
        self.oldMiterLimits = nil
        self.newMiterLimits = nil
        self.oldOpacities = nil
        self.newOpacities = nil
    }

    init(objectIDs: [UUID],
         lineCap old: [UUID: CGLineCap],
         new: [UUID: CGLineCap]) {
        self.objectIDs = objectIDs
        self.propertyType = .lineCap
        self.oldPlacements = nil
        self.newPlacements = nil
        self.oldLineJoins = nil
        self.newLineJoins = nil
        self.oldLineCaps = old
        self.newLineCaps = new
        self.oldMiterLimits = nil
        self.newMiterLimits = nil
        self.oldOpacities = nil
        self.newOpacities = nil
    }

    init(objectIDs: [UUID],
         miterLimit old: [UUID: Double],
         new: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.propertyType = .miterLimit
        self.oldPlacements = nil
        self.newPlacements = nil
        self.oldLineJoins = nil
        self.newLineJoins = nil
        self.oldLineCaps = nil
        self.newLineCaps = nil
        self.oldMiterLimits = old
        self.newMiterLimits = new
        self.oldOpacities = nil
        self.newOpacities = nil
    }

    init(objectIDs: [UUID],
         imageOpacity old: [UUID: Double],
         new: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.propertyType = .imageOpacity
        self.oldPlacements = nil
        self.newPlacements = nil
        self.oldLineJoins = nil
        self.newLineJoins = nil
        self.oldLineCaps = nil
        self.newLineCaps = nil
        self.oldMiterLimits = nil
        self.newMiterLimits = nil
        self.oldOpacities = old
        self.newOpacities = new
    }

    override func execute(on document: VectorDocument) {
        switch propertyType {
        case .placement:
            applyPlacements(newPlacements!, to: document)
        case .lineJoin:
            applyLineJoins(newLineJoins!, to: document)
        case .lineCap:
            applyLineCaps(newLineCaps!, to: document)
        case .miterLimit:
            applyMiterLimits(newMiterLimits!, to: document)
        case .imageOpacity:
            applyImageOpacities(newOpacities!, to: document)
        }
    }

    override func undo(on document: VectorDocument) {
        switch propertyType {
        case .placement:
            applyPlacements(oldPlacements!, to: document)
        case .lineJoin:
            applyLineJoins(oldLineJoins!, to: document)
        case .lineCap:
            applyLineCaps(oldLineCaps!, to: document)
        case .miterLimit:
            applyMiterLimits(oldMiterLimits!, to: document)
        case .imageOpacity:
            applyImageOpacities(oldOpacities!, to: document)
        }
    }

    private func applyPlacements(_ placements: [UUID: StrokePlacement], to document: VectorDocument) {

        for id in objectIDs {
            guard let placement = placements[id],
                  let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) else { continue }

            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType, !shape.isTextObject {
                shape.strokeStyle?.placement = placement
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: obj.orderID)
                document.unifiedObjects[index] = obj
            }
        }

    }

    private func applyLineJoins(_ lineJoins: [UUID: CGLineJoin], to document: VectorDocument) {

        for id in objectIDs {
            guard let lineJoin = lineJoins[id],
                  let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) else { continue }

            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType, !shape.isTextObject {
                shape.strokeStyle?.lineJoin = LineJoin(lineJoin)
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: obj.orderID)
                document.unifiedObjects[index] = obj
            }
        }

    }

    private func applyLineCaps(_ lineCaps: [UUID: CGLineCap], to document: VectorDocument) {

        for id in objectIDs {
            guard let lineCap = lineCaps[id],
                  let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) else { continue }

            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType, !shape.isTextObject {
                shape.strokeStyle?.lineCap = LineCap(lineCap)
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: obj.orderID)
                document.unifiedObjects[index] = obj
            }
        }

    }

    private func applyMiterLimits(_ miterLimits: [UUID: Double], to document: VectorDocument) {

        for id in objectIDs {
            guard let miterLimit = miterLimits[id],
                  let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) else { continue }

            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType, !shape.isTextObject {
                shape.strokeStyle?.miterLimit = miterLimit
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: obj.orderID)
                document.unifiedObjects[index] = obj
            }
        }

    }

    private func applyImageOpacities(_ opacities: [UUID: Double], to document: VectorDocument) {

        for id in objectIDs {
            guard let opacity = opacities[id],
                  let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) else { continue }

            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType, !shape.isTextObject {
                shape.opacity = opacity
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: obj.orderID)
                document.unifiedObjects[index] = obj
            }
        }

    }
}
