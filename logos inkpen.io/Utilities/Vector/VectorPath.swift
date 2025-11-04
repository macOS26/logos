import SwiftUI
import simd

struct FillRule: Codable, Hashable {
    private let rule: String

    init(_ rule: CGPathFillRule) {
        switch rule {
        case .evenOdd:
            self.rule = "evenOdd"
        case .winding:
            self.rule = "winding"
        @unknown default:
            self.rule = "winding"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rule = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rule)
    }

    var cgPathFillRule: CGPathFillRule {
        switch rule {
        case "evenOdd":
            return .evenOdd
        case "winding":
            return .winding
        default:
            return .winding
        }
    }

    static let winding = FillRule(.winding)
    static let evenOdd = FillRule(.evenOdd)
}

struct VectorPoint: Codable, Hashable {
    internal var simdPoint: SIMD2<Double>

    var x: Double {
        get { simdPoint.x }
        set { simdPoint.x = newValue }
    }

    var y: Double {
        get { simdPoint.y }
        set { simdPoint.y = newValue }
    }

    init(_ x: Double, _ y: Double) {
        self.simdPoint = SIMD2(x, y)
    }

    init(_ point: CGPoint) {
        self.simdPoint = SIMD2(Double(point.x), Double(point.y))
    }

    init(simd: SIMD2<Double>) {
        self.simdPoint = simd
    }

    var cgPoint: CGPoint {
        CGPoint(x: simdPoint.x, y: simdPoint.y)
    }

    static func + (lhs: VectorPoint, rhs: VectorPoint) -> VectorPoint {
        VectorPoint(simd: lhs.simdPoint + rhs.simdPoint)
    }

    static func - (lhs: VectorPoint, rhs: VectorPoint) -> VectorPoint {
        VectorPoint(simd: lhs.simdPoint - rhs.simdPoint)
    }

    static func * (lhs: VectorPoint, scalar: Double) -> VectorPoint {
        VectorPoint(simd: lhs.simdPoint * scalar)
    }

    static func / (lhs: VectorPoint, scalar: Double) -> VectorPoint {
        VectorPoint(simd: lhs.simdPoint / scalar)
    }

    enum CodingKeys: String, CodingKey {
        case x, y
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(simdPoint.x, forKey: .x)
        try container.encode(simdPoint.y, forKey: .y)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        self.simdPoint = SIMD2(x, y)
    }
}

struct BezierControlPoint: Codable, Hashable {
    var point: VectorPoint
    var inControl: VectorPoint?
    var outControl: VectorPoint?

    init(point: VectorPoint, inControl: VectorPoint? = nil, outControl: VectorPoint? = nil) {
        self.point = point
        self.inControl = inControl
        self.outControl = outControl
    }
}

enum AnchorPointType: String, Codable, Hashable {
    case corner      // Sharp point, no curves or independent angles
    case cusp        // Independent curves, no tangency
    case smooth      // 180° tangent curves
}

enum PathElement: Hashable {
    case move(to: VectorPoint, pointType: AnchorPointType = .corner)
    case line(to: VectorPoint, pointType: AnchorPointType = .corner)
    case curve(to: VectorPoint, control1: VectorPoint, control2: VectorPoint, pointType: AnchorPointType = .smooth)
    case quadCurve(to: VectorPoint, control: VectorPoint, pointType: AnchorPointType = .smooth)
    case close

    // Helper methods to extract destination point
    var destinationPoint: VectorPoint? {
        switch self {
        case .move(let to, _), .line(let to, _):
            return to
        case .curve(let to, _, _, _), .quadCurve(let to, _, _):
            return to
        case .close:
            return nil
        }
    }

    var pointType: AnchorPointType? {
        switch self {
        case .move(_, let type), .line(_, let type):
            return type
        case .curve(_, _, _, let type), .quadCurve(_, _, let type):
            return type
        case .close:
            return nil
        }
    }

    mutating func setPointType(_ type: AnchorPointType) {
        switch self {
        case .move(let to, _):
            self = .move(to: to, pointType: type)
        case .line(let to, _):
            self = .line(to: to, pointType: type)
        case .curve(let to, let c1, let c2, _):
            self = .curve(to: to, control1: c1, control2: c2, pointType: type)
        case .quadCurve(let to, let c, _):
            self = .quadCurve(to: to, control: c, pointType: type)
        case .close:
            break
        }
    }
}

// MARK: - Codable Implementation (Backward Compatible)
extension PathElement: Codable {
    enum CodingKeys: String, CodingKey {
        case move, line, curve, quadCurve, close
    }

    enum MoveCodingKeys: String, CodingKey {
        case to, pointType
    }

    enum LineCodingKeys: String, CodingKey {
        case to, pointType
    }

    enum CurveCodingKeys: String, CodingKey {
        case to, control1, control2, pointType
    }

    enum QuadCurveCodingKeys: String, CodingKey {
        case to, control, pointType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .move(let to, let pointType):
            var nested = container.nestedContainer(keyedBy: MoveCodingKeys.self, forKey: .move)
            try nested.encode(to, forKey: .to)
            try nested.encode(pointType, forKey: .pointType)

        case .line(let to, let pointType):
            var nested = container.nestedContainer(keyedBy: LineCodingKeys.self, forKey: .line)
            try nested.encode(to, forKey: .to)
            try nested.encode(pointType, forKey: .pointType)

        case .curve(let to, let control1, let control2, let pointType):
            var nested = container.nestedContainer(keyedBy: CurveCodingKeys.self, forKey: .curve)
            try nested.encode(to, forKey: .to)
            try nested.encode(control1, forKey: .control1)
            try nested.encode(control2, forKey: .control2)
            try nested.encode(pointType, forKey: .pointType)

        case .quadCurve(let to, let control, let pointType):
            var nested = container.nestedContainer(keyedBy: QuadCurveCodingKeys.self, forKey: .quadCurve)
            try nested.encode(to, forKey: .to)
            try nested.encode(control, forKey: .control)
            try nested.encode(pointType, forKey: .pointType)

        case .close:
            _ = container.nestedContainer(keyedBy: MoveCodingKeys.self, forKey: .close)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.move) {
            let nested = try container.nestedContainer(keyedBy: MoveCodingKeys.self, forKey: .move)
            let to = try nested.decode(VectorPoint.self, forKey: .to)
            // Backward compatible: use default if pointType is missing
            let pointType = try nested.decodeIfPresent(AnchorPointType.self, forKey: .pointType) ?? .corner
            self = .move(to: to, pointType: pointType)

        } else if container.contains(.line) {
            let nested = try container.nestedContainer(keyedBy: LineCodingKeys.self, forKey: .line)
            let to = try nested.decode(VectorPoint.self, forKey: .to)
            // Backward compatible: use default if pointType is missing
            let pointType = try nested.decodeIfPresent(AnchorPointType.self, forKey: .pointType) ?? .corner
            self = .line(to: to, pointType: pointType)

        } else if container.contains(.curve) {
            let nested = try container.nestedContainer(keyedBy: CurveCodingKeys.self, forKey: .curve)
            let to = try nested.decode(VectorPoint.self, forKey: .to)
            let control1 = try nested.decode(VectorPoint.self, forKey: .control1)
            let control2 = try nested.decode(VectorPoint.self, forKey: .control2)
            // Backward compatible: use default if pointType is missing
            let pointType = try nested.decodeIfPresent(AnchorPointType.self, forKey: .pointType) ?? .smooth
            self = .curve(to: to, control1: control1, control2: control2, pointType: pointType)

        } else if container.contains(.quadCurve) {
            let nested = try container.nestedContainer(keyedBy: QuadCurveCodingKeys.self, forKey: .quadCurve)
            let to = try nested.decode(VectorPoint.self, forKey: .to)
            let control = try nested.decode(VectorPoint.self, forKey: .control)
            // Backward compatible: use default if pointType is missing
            let pointType = try nested.decodeIfPresent(AnchorPointType.self, forKey: .pointType) ?? .smooth
            self = .quadCurve(to: to, control: control, pointType: pointType)

        } else if container.contains(.close) {
            self = .close

        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown PathElement type"
                )
            )
        }
    }
}

struct VectorPath: Codable, Hashable, Identifiable {
    var id: UUID
    var elements: [PathElement]
    var isClosed: Bool
    var fillRule: FillRule

    init(elements: [PathElement] = [], isClosed: Bool = false, fillRule: CGPathFillRule = .winding) {
        self.id = UUID()
        self.elements = elements
        self.isClosed = isClosed
        self.fillRule = FillRule(fillRule)
    }

    enum CodingKeys: String, CodingKey {
        case id, elements, isClosed, fillRule
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)

        if !elements.isEmpty {
            try container.encode(elements, forKey: .elements)
        }

        if isClosed {
            try container.encode(isClosed, forKey: .isClosed)
        }

        try container.encode(fillRule, forKey: .fillRule)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        elements = try container.decodeIfPresent([PathElement].self, forKey: .elements) ?? []
        isClosed = try container.decodeIfPresent(Bool.self, forKey: .isClosed) ?? false
        fillRule = try container.decode(FillRule.self, forKey: .fillRule)
    }

    init(cgPath: CGPath, fillRule: CGPathFillRule = .winding) {
        self.id = UUID()
        self.elements = []
        self.isClosed = false
        self.fillRule = FillRule(fillRule)

        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee

            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(point.x, point.y)))

            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(point.x, point.y)))

            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(point.x, point.y),
                    control: VectorPoint(control.x, control.y)
                ))

            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(point.x, point.y),
                    control1: VectorPoint(control1.x, control1.y),
                    control2: VectorPoint(control2.x, control2.y)
                ))

            case .closeSubpath:
                elements.append(.close)
                isClosed = true

            @unknown default:
                break
            }
        }
    }

    var cgPath: CGPath {
        let path = CGMutablePath()

        for element in elements {
            switch element {
            case .move(let to, _):
                path.move(to: to.cgPoint)
            case .line(let to, _):
                path.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2, _):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control, _):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                if !path.isEmpty {
                    path.closeSubpath()
                }
            }
        }

        if isClosed && !elements.contains(.close) && !path.isEmpty {
            path.closeSubpath()
        }

        return path
    }

    mutating func addElement(_ element: PathElement) {
        elements.append(element)
    }

    mutating func close() {
        if !isClosed {
            isClosed = true
            if !elements.contains(.close) {
                elements.append(.close)
            }
        }
    }
}

enum PathOperation: String, CaseIterable, Codable {
    case union = "Union"
    case intersect = "Intersect"
    case frontMinusBack = "Front Minus Back"
    case backMinusFront = "Back Minus Front"
    case exclude = "Exclude"

    var iconName: String {
        switch self {
        case .union: return "plus.circle"
        case .intersect: return "circle.circle"
        case .frontMinusBack: return "minus.circle"
        case .backMinusFront: return "minus.circle.fill"
        case .exclude: return "xmark.circle"
        }
    }
}
