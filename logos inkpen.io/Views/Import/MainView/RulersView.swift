import SwiftUI

struct RulersView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy

    private let rulerThickness: CGFloat = 20

    var body: some View {
        if document.showRulers {
            ZStack {
                HorizontalRuler(document: document, geometry: geometry)
                    .frame(height: rulerThickness)
                    .position(x: geometry.size.width / 2, y: rulerThickness / 2)

                VerticalRuler(document: document, geometry: geometry)
                    .frame(width: rulerThickness)
                    .position(x: rulerThickness / 2, y: geometry.size.height / 2)

                PageOriginCrosshair(document: document, geometry: geometry, rulerThickness: rulerThickness)
            }
        }
    }
}

struct HorizontalRuler: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy

    private let rulerThickness: CGFloat = 20

    var body: some View {
        GeometryReader { rulerGeometry in
            ZStack {
                Rectangle()
                    .fill(Color.ui.controlBackground)
                    .overlay(
                        Rectangle()
                            .stroke(Color.ui.lightGrayBorder, lineWidth: 0.5),
                        alignment: .bottom
                    )

                Canvas { context, size in
                    drawHorizontalRuler(context: context, size: size)
                }
            }
            .contentShape(Path { path in
                let size = rulerGeometry.size
                let hitRect = CGRect(x: rulerThickness, y: 0, width: max(0, size.width - rulerThickness), height: size.height)
                path.addRect(hitRect)
            })
            .contextMenu {
                Text("Units").font(.caption).foregroundColor(.secondary)
                ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                    Button(unit.rawValue) { setDocumentUnits(unit) }
                }
            }
            .onTapGesture {
            }
        }
    }

    private func setDocumentUnits(_ unit: MeasurementUnit) {
        document.settings.changeUnit(to: unit)
        document.onSettingsChanged()
    }

    private func drawHorizontalRuler(context: GraphicsContext, size: CGSize) {
        let unit = document.settings.unit
        let pointsPerUnit = unit.pointsPerUnit
        let zoomLevel = document.viewState.zoomLevel
        let canvasOffset = document.viewState.canvasOffset
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let startX = (-canvasOffset.x) / zoomLevel
        let endX = (size.width - canvasOffset.x) / zoomLevel
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)
        var loopStep = tickSpacing
        let majorTickInterval = getMajorTickInterval(for: unit, zoomLevel: zoomLevel)
        var x = floor(startX / tickSpacing) * tickSpacing
        while x <= endX {
            let rulerX = x * zoomLevel + canvasOffset.x

            if rulerX >= 0 && rulerX <= size.width {
                var isMajorTick = abs(x.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                var labelUsesMajor = isMajorTick
                let tickHeight: CGFloat
                let lineWidth: CGFloat
                if unit == .pixels || unit == .points {
                    if isMajorTick {
                        tickHeight = 16
                        lineWidth = 1.0
                    } else {
                        let positionInMajor = abs(x.truncatingRemainder(dividingBy: 50.0))
                        if abs(positionInMajor - 25.0) < 0.001 {
                            tickHeight = 10
                            lineWidth = 0.75
                        } else if abs(positionInMajor - 12.5) < 0.001 || abs(positionInMajor - 37.5) < 0.001 {
                            tickHeight = 6
                            lineWidth = 0.5
                        } else {
                            tickHeight = 4
                            lineWidth = 0.5
                        }
                    }
                } else if unit == .picas {
                    let majorStep = getMajorTickInterval(for: .picas, zoomLevel: zoomLevel)
                    let halfStep = majorStep / 2.0
                    let quarterStep = majorStep / 4.0
                    let eighthStep = majorStep / 8.0
                    let epsilon = 0.001
                    let isMajor = abs(x.truncatingRemainder(dividingBy: majorStep)) < epsilon
                    let isHalf = abs(x.truncatingRemainder(dividingBy: halfStep)) < epsilon
                    let isQuarter = abs(x.truncatingRemainder(dividingBy: quarterStep)) < epsilon
                    let isEighth = abs(x.truncatingRemainder(dividingBy: eighthStep)) < epsilon
                    let isThreePoint = abs(x.truncatingRemainder(dividingBy: 3.0)) < epsilon

                    if zoomLevel < 3.0 {
                        if isMajor {
                            tickHeight = 16
                            lineWidth = 1.0
                        } else if isHalf {
                            tickHeight = 12
                            lineWidth = 0.75
                        } else if isQuarter {
                            tickHeight = 8
                            lineWidth = 0.6
                        } else if isEighth {
                            tickHeight = 4
                            lineWidth = 0.5
                        } else if isThreePoint {
                            tickHeight = 3
                            lineWidth = 0.5
                        } else {
                            x += tickSpacing
                            continue
                        }
                    } else {
                        if isMajor {
                            tickHeight = 16
                            lineWidth = 1.0
                        } else if abs(x.truncatingRemainder(dividingBy: 6.0)) < epsilon {
                            tickHeight = 12
                            lineWidth = 0.75
                        } else if abs(x.truncatingRemainder(dividingBy: 3.0)) < epsilon {
                            tickHeight = 8
                            lineWidth = 0.6
                        } else if abs(x.truncatingRemainder(dividingBy: 1.0)) < epsilon {
                            tickHeight = 4
                            lineWidth = 0.5
                        } else {
                            x += tickSpacing
                            continue
                        }
                    }
                } else if unit == .centimeters || unit == .millimeters {
                    let mmPoints = MeasurementUnit.millimeters.pointsPerUnit
                    let mmIndex = Int(round(x / mmPoints))
                    let isCentimeter = (mmIndex % 10 == 0)
                    let isHalfCentimeter = (mmIndex % 5 == 0)
                    let desiredMinorMm = max(1, Int(round(tickSpacing / mmPoints)))
                    let stepMm: Int = (desiredMinorMm % 5 == 0) ? min(desiredMinorMm, 5) : 1
                    loopStep = Double(stepMm) * mmPoints

                    if unit == .centimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    } else if unit == .millimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    }

                    if !isCentimeter && !isHalfCentimeter {
                        if mmIndex % desiredMinorMm != 0 {
                            x += loopStep
                            continue
                        }
                    }

                    if isCentimeter {
                        tickHeight = 16
                        lineWidth = 1.0
                    } else if isHalfCentimeter {
                        tickHeight = 10
                        lineWidth = 0.7
                    } else {
                        tickHeight = 6
                        lineWidth = 0.5
                    }
                } else {
                    if isMajorTick {
                        tickHeight = 16
                        lineWidth = 1.0
                    } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 2)) < 0.001 {
                        tickHeight = 12
                        lineWidth = 0.75
                    } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 4)) < 0.001 {
                        tickHeight = 8
                        lineWidth = 0.6
                    } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 8)) < 0.001 {
                        tickHeight = 4
                        lineWidth = 0.5
                    } else if abs(x.truncatingRemainder(dividingBy: pointsPerUnit / 16)) < 0.001 {
                        tickHeight = 3
                        lineWidth = 0.5
                    } else {
                        x += tickSpacing
                        continue
                    }
                }

                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: rulerX, y: size.height - tickHeight))
                        path.addLine(to: CGPoint(x: rulerX, y: size.height))
                    },
                    with: .color(.primary),
                    lineWidth: lineWidth
                )

                if labelUsesMajor {
                    var labelText: String
                    if unit == .millimeters {
                        let mmValue = ((x - pageOrigin.x) / MeasurementUnit.millimeters.pointsPerUnit).rounded()
                        let mmInt = Int(mmValue)
                        labelText = String(mmInt)
                    } else {
                        let value = (x - pageOrigin.x) / pointsPerUnit
                        labelText = formatRulerValue(value, unit: unit)
                    }

                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.ui.primaryText)

                    let offsetX: CGFloat = 3
                    context.draw(text, at: CGPoint(x: rulerX + offsetX, y: size.height - 14), anchor: .leading)
                }
            }

            x += loopStep
        }
    }
}

struct VerticalRuler: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy

    private let rulerThickness: CGFloat = 20

    var body: some View {
        GeometryReader { rulerGeometry in
            ZStack {
                Rectangle()
                    .fill(Color.ui.controlBackground)
                    .overlay(
                        Rectangle()
                            .stroke(Color.ui.lightGrayBorder, lineWidth: 0.5),
                        alignment: .trailing
                    )
                    .offset(y: 0.5)

                Canvas { context, size in
                    var ctx = context
                    ctx.translateBy(x: 0, y: 0.5)
                    drawVerticalRuler(context: ctx, size: size)
                }
            }
            .contentShape(Path { path in
                let size = rulerGeometry.size
                let hitRect = CGRect(x: 0, y: rulerThickness, width: size.width, height: max(0, size.height - rulerThickness))
                path.addRect(hitRect)
            })
            .contextMenu {
                Text("Units").font(.caption).foregroundColor(.secondary)
                ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                    Button(unit.rawValue) {
                        document.settings.changeUnit(to: unit)
                        document.onSettingsChanged()
                    }
                }
            }
            .onTapGesture {
            }
        }
    }

    private func drawVerticalRuler(context: GraphicsContext, size: CGSize) {
        let unit = document.settings.unit
        let pointsPerUnit = unit.pointsPerUnit
        let zoomLevel = document.viewState.zoomLevel
        let canvasOffset = document.viewState.canvasOffset
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let startY = (-canvasOffset.y) / zoomLevel
        let endY = (size.height - canvasOffset.y) / zoomLevel
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)
        var loopStep = tickSpacing
        let majorTickInterval = getMajorTickInterval(for: unit, zoomLevel: zoomLevel)
        var y = floor(startY / tickSpacing) * tickSpacing
        while y <= endY {
            let rulerY = y * zoomLevel + canvasOffset.y

            if rulerY >= 0 && rulerY <= size.height {
                var isMajorTick = abs(y.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                var labelUsesMajor = isMajorTick
                let tickWidth: CGFloat
                let lineWidth: CGFloat
                if unit == .pixels || unit == .points {
                    if isMajorTick {
                        tickWidth = 16
                        lineWidth = 1.0
                    } else {
                        let positionInMajor = abs(y.truncatingRemainder(dividingBy: 50.0))
                        if abs(positionInMajor - 25.0) < 0.001 {
                            tickWidth = 10
                            lineWidth = 0.75
                        } else if abs(positionInMajor - 12.5) < 0.001 || abs(positionInMajor - 37.5) < 0.001 {
                            tickWidth = 6
                            lineWidth = 0.5
                        } else {
                            tickWidth = 4
                            lineWidth = 0.5
                        }
                    }
                } else if unit == .picas {
                    let majorStep = getMajorTickInterval(for: .picas, zoomLevel: zoomLevel)
                    let halfStep = majorStep / 2.0
                    let quarterStep = majorStep / 4.0
                    let eighthStep = majorStep / 8.0
                    let epsilon = 0.001
                    let isMajor = abs(y.truncatingRemainder(dividingBy: majorStep)) < epsilon
                    let isHalf = abs(y.truncatingRemainder(dividingBy: halfStep)) < epsilon
                    let isQuarter = abs(y.truncatingRemainder(dividingBy: quarterStep)) < epsilon
                    let isEighth = abs(y.truncatingRemainder(dividingBy: eighthStep)) < epsilon
                    let isThreePoint = abs(y.truncatingRemainder(dividingBy: 3.0)) < epsilon

                    if zoomLevel < 3.0 {
                        if isMajor {
                            tickWidth = 16
                            lineWidth = 1.0
                        } else if isHalf {
                            tickWidth = 12
                            lineWidth = 0.75
                        } else if isQuarter {
                            tickWidth = 8
                            lineWidth = 0.6
                        } else if isEighth {
                            tickWidth = 4
                            lineWidth = 0.5
                        } else if isThreePoint {
                            tickWidth = 3
                            lineWidth = 0.5
                        } else {
                            y += tickSpacing
                            continue
                        }
                    } else {
                        if isMajor {
                            tickWidth = 16
                            lineWidth = 1.0
                        } else if abs(y.truncatingRemainder(dividingBy: 6.0)) < epsilon {
                            tickWidth = 12
                            lineWidth = 0.75
                        } else if abs(y.truncatingRemainder(dividingBy: 3.0)) < epsilon {
                            tickWidth = 8
                            lineWidth = 0.6
                        } else if abs(y.truncatingRemainder(dividingBy: 1.0)) < epsilon {
                            tickWidth = 4
                            lineWidth = 0.5
                        } else {
                            y += tickSpacing
                            continue
                        }
                    }
                } else if unit == .centimeters || unit == .millimeters {
                    let mmPoints = MeasurementUnit.millimeters.pointsPerUnit
                    let mmIndex = Int(round(y / mmPoints))
                    let isCentimeter = (mmIndex % 10 == 0)
                    let isHalfCentimeter = (mmIndex % 5 == 0)
                    let desiredMinorMm = max(1, Int(round(tickSpacing / mmPoints)))
                    let stepMm: Int = (desiredMinorMm % 5 == 0) ? min(desiredMinorMm, 5) : 1
                    loopStep = Double(stepMm) * mmPoints

                    if unit == .centimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    } else if unit == .millimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    }

                    if !isCentimeter && !isHalfCentimeter {
                        if mmIndex % desiredMinorMm != 0 {
                            y += loopStep
                            continue
                        }
                    }

                    if isCentimeter {
                        tickWidth = 16
                        lineWidth = 1.0
                    } else if isHalfCentimeter {
                        tickWidth = 10
                        lineWidth = 0.7
                    } else {
                        tickWidth = 6
                        lineWidth = 0.5
                    }
                } else {
                    if isMajorTick {
                        tickWidth = 16
                        lineWidth = 1.0
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 2)) < 0.001 {
                        tickWidth = 12
                        lineWidth = 0.75
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 4)) < 0.001 {
                        tickWidth = 8
                        lineWidth = 0.6
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 8)) < 0.001 {
                        tickWidth = 4
                        lineWidth = 0.5
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 16)) < 0.001 {
                        tickWidth = 3
                        lineWidth = 0.5
                    } else {
                        y += tickSpacing
                        continue
                    }
                }

                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: size.width - tickWidth, y: rulerY))
                        path.addLine(to: CGPoint(x: size.width, y: rulerY))
                    },
                    with: .color(.primary),
                    lineWidth: lineWidth
                )

                if labelUsesMajor {
                    var labelText: String
                    if unit == .millimeters {
                        let mmValue = ((y - pageOrigin.y) / MeasurementUnit.millimeters.pointsPerUnit).rounded()
                        let mmInt = Int(mmValue)
                        labelText = String(mmInt)
                    } else {
                        let value = (y - pageOrigin.y) / pointsPerUnit
                        labelText = formatRulerValue(value, unit: unit)
                    }

                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.ui.primaryText)

                    var rotatedContext = context
                    rotatedContext.rotate(by: .degrees(-90))

                    let offsetX: CGFloat = 3
                    rotatedContext.draw(text, at: CGPoint(x: -rulerY + offsetX, y: size.width - 14), anchor: .leading)
                }
            }

            y += loopStep
        }
    }
}

private func getMajorTickInterval(for unit: MeasurementUnit, zoomLevel: Double) -> Double {
    let pointsPerUnit = unit.pointsPerUnit

    switch unit {
    case .pixels, .points:
        if zoomLevel >= 1.0 {
            return 50.0
        } else if zoomLevel >= 0.5 {
            return 100.0
        } else if zoomLevel >= 0.25 {
            return 200.0
        } else {
            return 400.0
        }
    case .inches:
        return pointsPerUnit
    case .centimeters:
        return pointsPerUnit
    case .millimeters:
        return pointsPerUnit * 10
    case .picas:
        if zoomLevel >= 4.0 {
            return pointsPerUnit * 1
        } else if zoomLevel >= 2.0 {
            return pointsPerUnit * 2
        } else if zoomLevel >= 1.0 {
            return pointsPerUnit * 4
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit * 8
        } else {
            return pointsPerUnit * 16
        }
    }
}

private func calculateTickSpacing(for unit: MeasurementUnit, zoomLevel: Double) -> Double {
    let pointsPerUnit = unit.pointsPerUnit

    switch unit {
    case .pixels, .points:
        if zoomLevel >= 1.0 {
            return 12.5
        } else if zoomLevel >= 0.5 {
            return 25.0
        } else if zoomLevel >= 0.25 {
            return 50.0
        } else {
            return 100.0
        }
    case .inches:
        if zoomLevel >= 1.0 {
            return pointsPerUnit / 16
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit / 8
        } else if zoomLevel >= 0.33 {
            return pointsPerUnit / 4
        } else if zoomLevel >= 0.25 {
            return pointsPerUnit / 2
        } else {
            return pointsPerUnit * 2
        }
    case .centimeters:
        let mmPoints = MeasurementUnit.millimeters.pointsPerUnit
        if zoomLevel >= 1.0 {
            return mmPoints * 1
        } else if zoomLevel >= 0.75 {
            return mmPoints * 2
        } else if zoomLevel >= 0.5 {
            return mmPoints * 4
        } else if zoomLevel >= 0.24 {
            return mmPoints * 12
        } else {
            return mmPoints * 16
        }
    case .millimeters:
        if zoomLevel >= 1.0 {
            return pointsPerUnit * 1
        } else if zoomLevel >= 0.75 {
            return pointsPerUnit * 2
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit * 4
        } else if zoomLevel >= 0.24 {
            return pointsPerUnit * 12
        } else {
            return pointsPerUnit * 16
        }
    case .picas:
        if zoomLevel >= 4.0 {
            return 1.0
        } else if zoomLevel >= 2.0 {
            return 1.0
        } else if zoomLevel >= 1.0 {
            return 1.0
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit
        } else {
            return pointsPerUnit * 2
        }
    }

}

private func formatRulerValue(_ value: Double, unit: MeasurementUnit) -> String {
    switch unit {
    case .inches:
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    case .centimeters:
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    case .millimeters:
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    case .points:
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    case .pixels:
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    case .picas:
        if value < 0 {
            return String(format: "-%.0f", abs(value))
        } else {
            return String(format: "%.0f", value)
        }
    }
}

struct GuidelinesView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    @State private var horizontalGuidelines: [Double] = []
    @State private var verticalGuidelines: [Double] = []

    var body: some View {
        ZStack {
            ForEach(horizontalGuidelines, id: \.self) { y in
                Rectangle()
                    .fill(Color.cyan)
                    .frame(height: 1)
                    .position(x: geometry.size.width / 2, y: y * document.viewState.zoomLevel + document.viewState.canvasOffset.y)
                    .opacity(0.7)
            }

            ForEach(verticalGuidelines, id: \.self) { x in
                Rectangle()
                    .fill(Color.cyan)
                    .frame(width: 1)
                    .position(x: x * document.viewState.zoomLevel + document.viewState.canvasOffset.x, y: geometry.size.height / 2)
                    .opacity(0.7)
            }
        }
    }
}

extension VectorDocument {
    func snapToGrid(_ point: CGPoint) -> CGPoint {
        guard snapToGrid else { return point }

        let gridSpacing = settings.gridSpacing * settings.unit.pointsPerUnit

        guard gridSpacing > 0 else { return point }

        let snappedX = round(point.x / gridSpacing) * gridSpacing
        let snappedY = round(point.y / gridSpacing) * gridSpacing

        return CGPoint(x: snappedX, y: snappedY)
    }

    func snapToGuidelines(_ point: CGPoint) -> CGPoint {
        return point
    }
}

struct UnitsConverter {
    static func convert(value: Double, from: MeasurementUnit, to: MeasurementUnit) -> Double {
        if from == to { return value }

        let points = value * from.pointsPerUnit

        return points / to.pointsPerUnit
    }

    static func formatValue(_ value: Double, unit: MeasurementUnit) -> String {
        let convertedValue = value / unit.pointsPerUnit

        switch unit {
        case .inches:
            return String(format: "%.3f in", convertedValue)
        case .centimeters:
            return String(format: "%.2f cm", convertedValue)
        case .millimeters:
            return String(format: "%.1f mm", convertedValue)
        case .points:
            return String(format: "%.0f pt", convertedValue)
        case .pixels:
            return String(format: "%.0f px", convertedValue)
        case .picas:
            return String(format: "%.2f pc", convertedValue)
        }
    }
}

private func gcd(_ a: Int, _ b: Int) -> Int {
    var x = abs(a)
    var y = abs(b)
    while y != 0 {
        let r = x % y
        x = y
        y = r
    }
    return max(1, x)
}

struct PageOriginCrosshair: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    let rulerThickness: CGFloat

    @State private var isDragging = false
    @State private var currentDragLocation: CGPoint?

    var body: some View {
        ZStack {
            CrosshairIcon()
                .frame(width: rulerThickness, height: rulerThickness)
                .position(x: rulerThickness / 2, y: rulerThickness / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            currentDragLocation = value.location
                        }
                        .onEnded { value in
                            isDragging = false
                            currentDragLocation = nil
                            updatePageOrigin(screenLocation: value.location)
                        }
                )

            if isDragging, let dragLocation = currentDragLocation {
                let snappedLocation = getSnappedScreenLocation(dragLocation)

                ForEach(getSnapPointsInScreenSpace(), id: \.debugDescription) { point in
                    Circle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .position(point)
                }

                Path { path in
                    path.move(to: CGPoint(x: snappedLocation.x, y: 0))
                    path.addLine(to: CGPoint(x: snappedLocation.x, y: geometry.size.height))
                }
                .stroke(Color.white, style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [5, 5]))

                Path { path in
                    path.move(to: CGPoint(x: snappedLocation.x, y: 0))
                    path.addLine(to: CGPoint(x: snappedLocation.x, y: geometry.size.height))
                }
                .stroke(Color(white: 0.3), style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [5, 5], dashPhase: 5))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: snappedLocation.y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: snappedLocation.y))
                }
                .stroke(Color.white, style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [5, 5]))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: snappedLocation.y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: snappedLocation.y))
                }
                .stroke(Color(white: 0.3), style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [5, 5], dashPhase: 5))
            }
        }
    }

    private func screenToCanvasPosition(_ screenPoint: CGPoint) -> CGPoint {
        let canvasScreenPoint = CGPoint(
            x: screenPoint.x - rulerThickness,
            y: screenPoint.y - rulerThickness
        )
        return CGPoint(
            x: (canvasScreenPoint.x - document.viewState.canvasOffset.x) / document.viewState.zoomLevel,
            y: (canvasScreenPoint.y - document.viewState.canvasOffset.y) / document.viewState.zoomLevel
        )
    }

    private func canvasToScreenPosition(_ canvasPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: canvasPoint.x * document.viewState.zoomLevel + document.viewState.canvasOffset.x,
            y: canvasPoint.y * document.viewState.zoomLevel + document.viewState.canvasOffset.y
        )
    }

    private func applySnapToCanvasPoint(_ canvasPoint: CGPoint) -> CGPoint {
        let canvasWidth = document.settings.sizeInPoints.width
        let canvasHeight = document.settings.sizeInPoints.height
        let snapThreshold: CGFloat = 10.0

        let snapPoints: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: canvasWidth, y: 0),
            CGPoint(x: 0, y: canvasHeight),
            CGPoint(x: canvasWidth, y: canvasHeight),

            CGPoint(x: canvasWidth / 2, y: 0),
            CGPoint(x: canvasWidth / 2, y: canvasHeight),
            CGPoint(x: 0, y: canvasHeight / 2),
            CGPoint(x: canvasWidth, y: canvasHeight / 2),

            CGPoint(x: canvasWidth / 2, y: canvasHeight / 2)
        ]

        var closestPoint: CGPoint?
        var closestDistance: CGFloat = snapThreshold

        for snapPoint in snapPoints {
            let distance = hypot(canvasPoint.x - snapPoint.x, canvasPoint.y - snapPoint.y)
            if distance < closestDistance {
                closestDistance = distance
                closestPoint = snapPoint
            }
        }

        return closestPoint ?? canvasPoint
    }

    private func getSnappedScreenLocation(_ screenPoint: CGPoint) -> CGPoint {
        let canvasPoint = screenToCanvasPosition(screenPoint)
        let snappedCanvasPoint = applySnapToCanvasPoint(canvasPoint)
        return canvasToScreenPosition(snappedCanvasPoint)
    }

    private func getSnapPointsInScreenSpace() -> [CGPoint] {
        let canvasWidth = document.settings.sizeInPoints.width
        let canvasHeight = document.settings.sizeInPoints.height
        let canvasSnapPoints: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: canvasWidth, y: 0),
            CGPoint(x: 0, y: canvasHeight),
            CGPoint(x: canvasWidth, y: canvasHeight),
            CGPoint(x: canvasWidth / 2, y: 0),
            CGPoint(x: canvasWidth / 2, y: canvasHeight),
            CGPoint(x: 0, y: canvasHeight / 2),
            CGPoint(x: canvasWidth, y: canvasHeight / 2),
            CGPoint(x: canvasWidth / 2, y: canvasHeight / 2)
        ]

        return canvasSnapPoints.map { canvasToScreenPosition($0) }
    }

    private func updatePageOrigin(screenLocation: CGPoint) {
        let canvasPoint = screenToCanvasPosition(screenLocation)
        let snappedCanvasPoint = applySnapToCanvasPoint(canvasPoint)

        document.settings.pageOrigin = snappedCanvasPoint
        document.onSettingsChanged()
    }
}

struct CrosshairIcon: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.ui.controlBackground)

                Path { path in
                    let padding: CGFloat = 1
                    path.move(to: CGPoint(x: padding, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width - padding, y: geometry.size.height / 2))
                    path.move(to: CGPoint(x: geometry.size.width / 2, y: padding))
                    path.addLine(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - padding))
                }
                .stroke(Color.gray, style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [1, 1]))

                Rectangle()
                    .stroke(Color.ui.lightGrayBorder, lineWidth: 0.5)
            }
        }
        .contentShape(Rectangle())
    }
}

extension CGSize {
    var asCGPoint: CGPoint {
        CGPoint(x: width, y: height)
    }
}

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
