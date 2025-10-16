import SwiftUI
import Combine

extension VectorDocument {

    func addColorToCurrentMode(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            if !customRgbSwatches.contains(color) {
                customRgbSwatches.append(color)
            }
        case .cmyk:
            if !customCmykSwatches.contains(color) {
                customCmykSwatches.append(color)
            }
        case .pms:
            if !customHsbSwatches.contains(color) {
                customHsbSwatches.append(color)
            }
        }
    }

    func addColorSwatch(_ color: VectorColor) {
        addColorToCurrentMode(color)
    }

    func addColorToSwatches(_ color: VectorColor) {
        addColorToCurrentMode(color)
    }

    func removeColorFromCurrentMode(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            customRgbSwatches.removeAll { $0 == color }
        case .cmyk:
            customCmykSwatches.removeAll { $0 == color }
        case .pms:
            customHsbSwatches.removeAll { $0 == color }
        }
    }

    func notifyActiveToolsOfFillOpacityChange() {
        lastColorChangeType = .fillOpacity
        colorChangeNotification = UUID()
    }

    func notifyActiveToolsOfStrokeColorChange() {
        lastColorChangeType = .strokeColor
        colorChangeNotification = UUID()
    }

    func notifyActiveToolsOfStrokeOpacityChange() {
        lastColorChangeType = .strokeOpacity
        colorChangeNotification = UUID()
    }

    func notifyActiveToolsOfColorChange() {
        lastColorChangeType = .fillOpacity
        colorChangeNotification = UUID()
    }

    private func applyColorToShape(_ shape: inout VectorShape, color: VectorColor) {
        if shape.isTextObject {
            switch activeColorTarget {
            case .fill:
                if shape.typography != nil {
                    shape.typography?.fillColor = color
                    shape.typography?.fillOpacity = defaultFillOpacity
                }
            case .stroke:
                if shape.typography != nil {
                    shape.typography?.hasStroke = true
                    shape.typography?.strokeColor = color
                }
            }
        } else {
            switch activeColorTarget {
            case .fill:
                if shape.fillStyle == nil {
                    shape.fillStyle = FillStyle(color: color)
                } else {
                    shape.fillStyle?.color = color
                }
            case .stroke:
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: color, placement: .center)
                } else {
                    shape.strokeStyle?.color = color
                }
            }
        }
    }

    func setActiveColor(_ color: VectorColor) {
        let shouldSaveUndo = !selectedObjectIDs.isEmpty

        var oldColors: [UUID: VectorColor] = [:]
        var newColors: [UUID: VectorColor] = [:]
        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]

        for objectID in selectedObjectIDs {
            if let unifiedObject = findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .text(let shape):
                    switch activeColorTarget {
                    case .fill:
                        oldColors[objectID] = shape.typography?.fillColor ?? .black
                        newColors[objectID] = color
                        oldOpacities[objectID] = shape.typography?.fillOpacity ?? defaultFillOpacity
                        newOpacities[objectID] = defaultFillOpacity
                    case .stroke:
                        oldColors[objectID] = shape.typography?.strokeColor ?? .clear
                        newColors[objectID] = color
                        oldOpacities[objectID] = shape.typography?.strokeOpacity ?? defaultStrokeOpacity
                        newOpacities[objectID] = defaultStrokeOpacity
                    }
                case .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    switch activeColorTarget {
                    case .fill:
                        oldColors[objectID] = shape.fillStyle?.color ?? .black
                        newColors[objectID] = color
                        oldOpacities[objectID] = shape.fillStyle?.opacity ?? defaultFillOpacity
                        newOpacities[objectID] = defaultFillOpacity
                    case .stroke:
                        oldColors[objectID] = shape.strokeStyle?.color ?? .clear
                        newColors[objectID] = color
                        oldOpacities[objectID] = shape.strokeStyle?.opacity ?? defaultStrokeOpacity
                        newOpacities[objectID] = defaultStrokeOpacity
                    }
                }
            }
        }

        if shouldSaveUndo && !oldColors.isEmpty {
            let commandTarget: ChangeColorCommand.ColorTarget = (activeColorTarget == .fill) ? .fill : .stroke
            let command = ChangeColorCommand(
                objectIDs: Array(selectedObjectIDs),
                target: commandTarget,
                oldColors: oldColors,
                newColors: newColors,
                oldOpacities: oldOpacities,
                newOpacities: newOpacities
            )
            executeCommand(command)
        }

        switch activeColorTarget {
        case .fill:
            defaultFillColor = color
        case .stroke:
            defaultStrokeColor = color
        }

        for objectID in selectedObjectIDs {
            if let unifiedObject = findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .group(let groupShape):
                    for childShape in groupShape.groupedShapes {
                        updateShapeByID(childShape.id) { shape in
                            applyColorToShape(&shape, color: color)
                        }
                    }
                case .shape, .text, .warp, .clipGroup, .clipMask:
                    updateShapeByID(objectID) { shape in
                        applyColorToShape(&shape, color: color)
                    }
                }
            }
        }
    }

    func removeColorSwatch(_ color: VectorColor) {
        removeColorFromCurrentMode(color)
    }

    func getSelectedObjectColor() -> VectorColor? {
        guard let firstSelectedID = selectedObjectIDs.first else { return nil }

        if let unifiedObject = findObject(by: firstSelectedID) {
            switch unifiedObject.objectType {
            case .text(let shape):
                if activeColorTarget == .stroke {
                    return shape.typography?.strokeColor
                } else {
                    return shape.typography?.fillColor
                }
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if activeColorTarget == .stroke {
                    return shape.strokeStyle?.color
                } else {
                    return shape.fillStyle?.color
                }
            }
        }

        return nil
    }

    func updateColorSwatchesForMode() {
    }

    static func createDefaultRGBSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        let rgbColors: [VectorColor] = [
            .rgb(RGBColor(red: 1, green: 0, blue: 0)),
            .rgb(RGBColor(red: 0, green: 1, blue: 0)),
            .rgb(RGBColor(red: 0, green: 0, blue: 1)),
            .rgb(RGBColor(red: 1, green: 1, blue: 0)),
            .rgb(RGBColor(red: 1, green: 0, blue: 1)),
            .rgb(RGBColor(red: 0, green: 1, blue: 1)),
            .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5)),
            .rgb(RGBColor(red: 1, green: 0.5, blue: 0)),
            .rgb(RGBColor(red: 0.5, green: 0, blue: 0.5)),
            .rgb(RGBColor(red: 0, green: 0.5, blue: 0)),
            .rgb(RGBColor(red: 0, green: 0, blue: 0.5)),
            .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0)),
        ]

        let p3Colors: [VectorColor] = [
            .rgb(RGBColor(red: 0.0, green: 0.478, blue: 1.0)),
            .rgb(RGBColor(red: 1.0, green: 0.231, blue: 0.188)),
            .rgb(RGBColor(red: 0.204, green: 0.780, blue: 0.349)),
            .rgb(RGBColor(red: 1.0, green: 0.800, blue: 0.0)),
            .rgb(RGBColor(red: 1.0, green: 0.584, blue: 0.0)),
            .rgb(RGBColor(red: 0.686, green: 0.322, blue: 0.871)),
            .rgb(RGBColor(red: 1.0, green: 0.176, blue: 0.333)),
            .rgb(RGBColor(red: 0.353, green: 0.784, blue: 0.980)),
            .rgb(RGBColor(red: 0.345, green: 0.337, blue: 0.839)),
            .rgb(RGBColor(red: 0.635, green: 0.518, blue: 0.368)),
            .rgb(RGBColor(red: 0.557, green: 0.557, blue: 0.576)),
            .rgb(RGBColor(red: 0.682, green: 0.682, blue: 0.698)),
            .rgb(RGBColor(red: 0.780, green: 0.780, blue: 0.800))
        ]

        return basicColors + rgbColors + p3Colors
    }

    static func createDefaultCMYKSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        var cmykColors: [VectorColor] = []
        let cmykValues = [
            (100, 0, 0, 0),
            (0, 100, 0, 0),
            (0, 0, 100, 0),
            (0, 0, 0, 100),

            (100, 100, 0, 0),
            (0, 100, 100, 0),
            (100, 0, 100, 0),

            (100, 0, 0, 25),
            (0, 100, 0, 25),
            (0, 0, 100, 25),

            (0, 0, 0, 25),
            (0, 0, 0, 50),
            (0, 0, 0, 75),

            (30, 30, 30, 100),
            (40, 40, 40, 100),

            (0, 30, 45, 0),
            (0, 40, 60, 10),
            (0, 50, 75, 25),
        ]

        for (c, m, y, k) in cmykValues {
            let cmykColor = CMYKColor(
                cyan: Double(c) / 100.0,
                magenta: Double(m) / 100.0,
                yellow: Double(y) / 100.0,
                black: Double(k) / 100.0
            )
            cmykColors.append(.cmyk(cmykColor))
        }

        return basicColors + cmykColors
    }

    static func createDefaultHSBSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        var hsbColors: [VectorColor] = []

        for hue in stride(from: 0, to: 360, by: 30) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 1.0, brightness: 1.0)
            hsbColors.append(.hsb(hsbColor))
        }

        for hue in stride(from: 0, to: 360, by: 60) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 0.5, brightness: 0.8)
            hsbColors.append(.hsb(hsbColor))
        }

        for hue in stride(from: 0, to: 360, by: 90) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 0.8, brightness: 0.5)
            hsbColors.append(.hsb(hsbColor))
        }

        return basicColors + hsbColors
    }
}
