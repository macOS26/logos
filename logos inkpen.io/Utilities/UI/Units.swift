import SwiftUI
import AppKit

enum MeasurementUnit: String, CaseIterable, Codable {
    case inches = "Inches"
    case centimeters = "cm"
    case millimeters = "mm"
    case points = "Points"
    case pixels = "Pixels"
    case picas = "Picas"

    var abbreviation: String {
        switch self {
        case .inches: return "in"
        case .centimeters: return "cm"
        case .millimeters: return "mm"
        case .points: return "pt"
        case .pixels: return "px"
        case .picas: return "pc"
        }
    }

    var pointsPerUnit: Double {
        switch self {
        case .inches: return 72.0
        case .centimeters: return 28.346
        case .millimeters: return 2.835
        case .points: return 1.0
        case .pixels: return 1.0
        case .picas: return 12.0
        }
    }

    /// Default grid spacing in the unit's native measurement (not points).
    var defaultGridSpacing: Double {
        switch self {
        case .inches: return 0.125      // 1/8 inch
        case .centimeters: return 0.5   // 5mm
        case .millimeters: return 1.0   // 1mm
        case .points: return 9.0        // 9pt (1/8 inch)
        case .pixels: return 10.0       // 10px
        case .picas: return 1.0         // 1 pica
        }
    }

    /// Default grid spacing converted to points
    var defaultGridSpacingInPoints: Double {
        return toPoints(defaultGridSpacing)
    }

    /// Number of minor grid lines between major lines
    var majorGridInterval: Int {
        switch self {
        case .inches: return 8       // Major line every 1" (8 × 1/8")
        case .centimeters: return 2  // Major line every 1cm (2 × 5mm)
        case .millimeters: return 5  // Major line every 5mm
        case .points: return 8       // Major line every 72pt/1" (8 × 9pt)
        case .pixels: return 10      // Major line every 100px
        case .picas: return 6        // Major line every 6pc/1"
        }
    }

    /// Convert points to this measurement unit
    func fromPoints(_ points: Double) -> Double {
        return points / pointsPerUnit
    }

    /// Convert from this measurement unit to points
    func toPoints(_ value: Double) -> Double {
        return value * pointsPerUnit
    }

    /// Format a value in this unit with appropriate decimal precision
    func format(_ value: Double) -> String {
        return String(format: "%.3f", value)
    }
}

enum ZoomMode: Equatable {
    case zoomIn
    case zoomOut
    case fitToPage
    case actualSize
    case custom(CGPoint)
}

struct ZoomRequest: Equatable {
    let targetZoom: CGFloat
    let mode: ZoomMode

    init(targetZoom: CGFloat, mode: ZoomMode) {
        self.targetZoom = targetZoom
        self.mode = mode
    }
}
