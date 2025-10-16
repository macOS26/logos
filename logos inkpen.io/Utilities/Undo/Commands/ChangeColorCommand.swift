import Foundation
import Combine

class ChangeColorCommand: BaseCommand {
    enum ColorTarget {
        case fill
        case stroke
    }

    private let objectIDs: [UUID]
    private let target: ColorTarget
    private let oldColors: [UUID: VectorColor]
    private let newColors: [UUID: VectorColor]
    private let oldOpacities: [UUID: Double]
    private let newOpacities: [UUID: Double]

    init(objectIDs: [UUID],
         target: ColorTarget,
         oldColors: [UUID: VectorColor],
         newColors: [UUID: VectorColor],
         oldOpacities: [UUID: Double],
         newOpacities: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.target = target
        self.oldColors = oldColors
        self.newColors = newColors
        self.oldOpacities = oldOpacities
        self.newOpacities = newOpacities
    }

    override func execute(on document: VectorDocument) {
        applyColors(newColors, opacities: newOpacities, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyColors(oldColors, opacities: oldOpacities, to: document)
    }

    private func applyColors(_ colors: [UUID: VectorColor],
                             opacities: [UUID: Double],
                             to document: VectorDocument) {

        for id in objectIDs {
            if let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) {
                var obj = document.unifiedObjects[index]

                if case .shape(var shape) = obj.objectType {
                    if let color = colors[id], let opacity = opacities[id] {
                        if shape.isTextObject {
                            if var typography = shape.typography {
                                switch target {
                                case .fill:
                                    typography.fillColor = color
                                    typography.fillOpacity = opacity
                                case .stroke:
                                    typography.strokeColor = color
                                    typography.strokeOpacity = opacity
                                }
                                shape.typography = typography
                            }
                        } else {
                            switch target {
                            case .fill:
                                shape.fillStyle?.color = color
                                shape.fillStyle?.opacity = opacity
                            case .stroke:
                                shape.strokeStyle?.color = color
                                shape.strokeStyle?.opacity = opacity
                            }
                        }
                    }
                    obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                    document.unifiedObjects[index] = obj
                }
            }
        }

    }
}
