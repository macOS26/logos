import SwiftUI

// MARK: - Stroke Defaults

struct StrokeDefaults: Equatable {
    var placement: StrokePlacement
    var lineJoin: CGLineJoin
    var lineCap: CGLineCap
    var miterLimit: Double

    static let `default` = StrokeDefaults(
        placement: .center,
        lineJoin: .miter,
        lineCap: .butt,
        miterLimit: 10.0
    )
}

extension StrokeDefaults: Codable {
    enum CodingKeys: String, CodingKey {
        case placement, lineJoin, lineCap, miterLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placement = try container.decode(StrokePlacement.self, forKey: .placement)
        let lineJoinRaw = try container.decode(Int32.self, forKey: .lineJoin)
        lineJoin = CGLineJoin(rawValue: lineJoinRaw) ?? .miter
        let lineCapRaw = try container.decode(Int32.self, forKey: .lineCap)
        lineCap = CGLineCap(rawValue: lineCapRaw) ?? .butt
        miterLimit = try container.decode(Double.self, forKey: .miterLimit)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(placement, forKey: .placement)
        try container.encode(lineJoin.rawValue, forKey: .lineJoin)
        try container.encode(lineCap.rawValue, forKey: .lineCap)
        try container.encode(miterLimit, forKey: .miterLimit)
    }
}

// MARK: - Grid Settings

struct GridSettings: Codable, Equatable {
    var showRulers: Bool
    var showGrid: Bool
    var snapToGrid: Bool
    var snapToPoint: Bool
    var gridSpacing: Double
    var gridOnTop: Bool

    static let `default` = GridSettings(
        showRulers: false,
        showGrid: false,
        snapToGrid: false,
        snapToPoint: false,
        gridSpacing: 12.0,
        gridOnTop: false
    )
}

// MARK: - Color Swatches

struct ColorSwatches: Codable, Equatable {
    var rgb: [VectorColor]
    var cmyk: [VectorColor]
    var hsb: [VectorColor]

    static let empty = ColorSwatches(
        rgb: [],
        cmyk: [],
        hsb: []
    )
}
