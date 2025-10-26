import Foundation
import CoreGraphics

class GradientCommand: BaseCommand {
    enum GradientTarget {
        case fill
        case stroke
    }

    private let objectIDs: [UUID]
    private let target: GradientTarget
    private let oldGradients: [UUID: VectorGradient?]
    private let newGradients: [UUID: VectorGradient?]
    private let oldOpacities: [UUID: Double]
    private let newOpacities: [UUID: Double]

    init(objectIDs: [UUID],
         target: GradientTarget,
         oldGradients: [UUID: VectorGradient?],
         newGradients: [UUID: VectorGradient?],
         oldOpacities: [UUID: Double],
         newOpacities: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.target = target
        self.oldGradients = oldGradients
        self.newGradients = newGradients
        self.oldOpacities = oldOpacities
        self.newOpacities = newOpacities
    }

    override func execute(on document: VectorDocument) {
        applyGradients(newGradients, opacities: newOpacities, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyGradients(oldGradients, opacities: oldOpacities, to: document)
    }

    private func applyGradients(_ gradients: [UUID: VectorGradient?], opacities: [UUID: Double], to document: VectorDocument) {
        for id in objectIDs {
            guard let gradient = gradients[id],
                  let opacity = opacities[id],
                  let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) else { continue }
            var obj = document.unifiedObjects[index]

            switch obj.objectType {
            case .shape(var shape), .image(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                switch target {
                case .fill:
                    if let gradient = gradient {
                        shape.fillStyle = FillStyle(gradient: gradient, opacity: opacity)
                    }
                case .stroke:
                    if let gradient = gradient {
                        let currentStroke = shape.strokeStyle
                        shape.strokeStyle = StrokeStyle(
                            gradient: gradient,
                            width: currentStroke?.width ?? 1.0,
                            placement: currentStroke?.placement ?? .center,
                            lineCap: currentStroke?.lineCap.cgLineCap ?? .butt,
                            lineJoin: currentStroke?.lineJoin.cgLineJoin ?? .miter,
                            miterLimit: currentStroke?.miterLimit ?? 10.0,
                            opacity: opacity
                        )
                    }
                }
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.unifiedObjects[index] = obj
            case .text:
                break
            }
        }
    }
}
