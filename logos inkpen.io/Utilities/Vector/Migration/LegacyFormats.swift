import Foundation

// MARK: - Legacy Format Structures
// WARNING: These structures are ONLY for migration purposes
// DO NOT use these in the main app code

/// Represents the inkpen document format version 1.0 (LEGACY)
struct LegacyDocument_v1_0: Codable {
    let unifiedObjects: [VectorObject]  // VectorObject is already Codable, reuse it
    let layers: [LegacyLayer]
    let settings: DocumentSettings
    let canvasOffset: [Double]?
    let currentTool: String?
    let viewMode: String?
    let zoomLevel: Double?
}

struct LegacyLayer: Codable {
    let id: UUID
    let name: String
    let color: String
    let isLocked: Bool?
}
