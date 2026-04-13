import Foundation
import CoreGraphics

// Minimal type stubs matching inkpen's actual types so FreeHand2Parser.swift compiles unmodified

struct VectorPoint {
    let x: Double
    let y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

enum PathElement {
    case move(to: VectorPoint)
    case line(to: VectorPoint)
    case curve(to: VectorPoint, control1: VectorPoint, control2: VectorPoint)
    case quadCurve(to: VectorPoint, control: VectorPoint)
    case close
}

struct RGBColor {
    let red: Double, green: Double, blue: Double, alpha: Double
    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
}

struct GradientStop {
    let position: Double
    let color: VectorColor
}

enum GradientUnits { case objectBoundingBox, userSpaceOnUse }
enum GradientSpreadMethod { case pad, reflect, repeatSpread }

struct LinearGradient {
    var id = UUID()
    var startPoint: CGPoint
    var endPoint: CGPoint
    var stops: [GradientStop]
    var spreadMethod: GradientSpreadMethod = .pad
    var units: GradientUnits = .objectBoundingBox
}

struct RadialGradient {
    var id = UUID()
    var centerPoint: CGPoint
    var radius: Double
    var stops: [GradientStop]
}

enum VectorGradient {
    case linear(LinearGradient)
    case radial(RadialGradient)
}

enum VectorColor: Equatable {
    case rgb(RGBColor)
    case black
    case white
    case gradient(VectorGradient)

    static func == (lhs: VectorColor, rhs: VectorColor) -> Bool {
        switch (lhs, rhs) {
        case (.black, .black), (.white, .white): return true
        case (.rgb(let a), .rgb(let b)):
            return a.red == b.red && a.green == b.green && a.blue == b.blue
        default: return false
        }
    }

    var rgbValues: (Double, Double, Double) {
        switch self {
        case .rgb(let c): return (c.red, c.green, c.blue)
        case .black: return (0, 0, 0)
        case .white: return (1, 1, 1)
        case .gradient: return (0.5, 0.5, 0.5) // placeholder for gradient
        }
    }
}

enum FillRule { case winding, evenOdd }

struct VectorPath {
    let elements: [PathElement]
    let isClosed: Bool
    let fillRule: FillRule
}

struct FillStyle {
    let color: VectorColor
}

struct StrokeStyle {
    let color: VectorColor
    let width: Double
    init(color: VectorColor, width: Double = 0.5) {
        self.color = color; self.width = width
    }
}

enum GeometricShapeType {
    case rectangle, square, circle, ellipse, triangle, pentagon, hexagon, line
}

struct VectorShape {
    var name: String
    let path: VectorPath
    let geometricType: GeometricShapeType?
    let strokeStyle: StrokeStyle?
    let fillStyle: FillStyle?
    let opacity: Double

    init(name: String, path: VectorPath, geometricType: GeometricShapeType?,
         strokeStyle: StrokeStyle?, fillStyle: FillStyle?, opacity: Double = 1.0,
         isCompoundPath: Bool = false) {
        self.name = name; self.path = path; self.geometricType = geometricType
        self.strokeStyle = strokeStyle; self.fillStyle = fillStyle; self.opacity = opacity
    }
}

enum FreeHandImportError: Error {
    case notSupported, parseFailed(code: Int), emptyOutput, allocationFailed
}

enum FreeHandDirectImporter {
    struct Stats {
        let paths, groups, clipGroups, compositePaths, newBlends, symbolInstances, contentIdPaths: Int
    }
    struct Result {
        let shapes: [VectorShape]
        let pageSize: CGSize
        let stats: Stats
    }
}

struct PathShapeDetector {
    struct Detection { let type: GeometricShapeType; let name: String }
    static func detect(elements: [PathElement]) -> Detection? { return nil }
}

struct ApplicationSettings {
    static let shared = ApplicationSettings()
    let importFreeHandEffects = true
}
