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
        // print("⚡️⚡️⚡️ GradientCommand.execute() called")
        // print("⚡️⚡️⚡️ Stack trace:")
        Thread.callStackSymbols.prefix(10).forEach { print("  \($0)") }
        applyGradients(newGradients, opacities: newOpacities, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyGradients(oldGradients, opacities: oldOpacities, to: document)
    }

    private func applyGradients(_ gradients: [UUID: VectorGradient?], opacities: [UUID: Double], to document: VectorDocument) {
        var affectedLayers = Set<Int>()

        for id in objectIDs {
            guard let gradient = gradients[id],
                  let opacity = opacities[id],
                  var obj = document.snapshot.objects[id] else { continue }

            // print("⚡️ GradientCommand: Applying to object \(id)")

            switch obj.objectType {
            case .shape(var shape), .image(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                switch target {
                case .fill:
                    if let gradient = gradient {
                        // print("⚡️ GradientCommand: BEFORE fill = \(shape.fillStyle?.color ?? .clear)")
                        // print("⚡️ GradientCommand: BEFORE stroke = \(shape.strokeStyle?.color ?? .clear)")
                        shape.fillStyle = FillStyle(gradient: gradient, opacity: opacity)
                        // print("⚡️ GradientCommand: AFTER fill = \(shape.fillStyle?.color ?? .clear)")
                        // print("⚡️ GradientCommand: AFTER stroke = \(shape.strokeStyle?.color ?? .clear)")
                        if let fillGradient = shape.fillStyle?.gradient {
                            // print("⚡️ GradientCommand: Applied gradient stops = \(fillGradient.stops.map { $0.color })")
                        }
                    }
                case .stroke:
                    if let gradient = gradient {
                        // print("⚡️ GradientCommand: BEFORE fill = \(shape.fillStyle?.color ?? .clear)")
                        // print("⚡️ GradientCommand: BEFORE stroke = \(shape.strokeStyle?.color ?? .clear)")
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
                        // print("⚡️ GradientCommand: AFTER fill = \(shape.fillStyle?.color ?? .clear)")
                        // print("⚡️ GradientCommand: AFTER stroke = \(shape.strokeStyle?.color ?? .clear)")
                    }
                }
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.snapshot.objects[id] = obj
                // print("⚡️ GradientCommand: Updated snapshot.objects[\(id)]")
                affectedLayers.insert(obj.layerIndex)
            case .text:
                break
            }
        }

        // print("⚡️ GradientCommand: Triggering layer updates for \(affectedLayers.count) layers")
        // Trigger layer updates so SwiftUI re-renders
        document.triggerLayerUpdates(for: affectedLayers)
        // print("⚡️ GradientCommand: Layer updates triggered")
    }
}
