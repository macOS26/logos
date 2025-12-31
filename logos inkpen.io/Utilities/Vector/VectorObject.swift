import SwiftUI

struct VectorObject: Identifiable, Hashable {
    let id: UUID
    let layerIndex: Int  // DEPRECATED: Layer membership now tracked via Layer.objectIDs
    let objectType: ObjectType

    enum ObjectType: Hashable {
        case shape(VectorShape)
        case text(VectorShape)
        case image(VectorShape)
        case warp(VectorShape)
        case group(VectorShape)
        case clipGroup(VectorShape)
        case clipMask(VectorShape)
        case guide(VectorShape)
    }

    // New explicit initializer - preferred
    init(id: UUID, layerIndex: Int, objectType: ObjectType) {
        self.id = id
        self.layerIndex = layerIndex
        self.objectType = objectType
    }

    // Helper to determine object type from shape properties
    static func determineType(for shape: VectorShape) -> ObjectType {
        if shape.isGuide {
            return .guide(shape)
        } else if shape.typography != nil {
            return .text(shape)
        } else if shape.embeddedImageData != nil || shape.linkedImagePath != nil {
            return .image(shape)
        } else if shape.isClippingPath {
            return .clipMask(shape)
        } else if shape.isClippingGroup {
            return .clipGroup(shape)
        } else if shape.isGroup && (!shape.memberIDs.isEmpty || !shape.groupedShapes.isEmpty) {
            return .group(shape)
        } else if shape.isWarpObject {
            return .warp(shape)
        } else {
            return .shape(shape)
        }
    }

    // Legacy initializer - kept for compatibility, will be removed later
    init(shape: VectorShape, layerIndex: Int) {
        self.id = shape.id
        self.layerIndex = layerIndex
        self.objectType = VectorObject.determineType(for: shape)
    }

    var isVisible: Bool {
        switch objectType {
        case .shape(let shape),
             .text(let shape),
             .image(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape),
             .guide(let shape):
            return shape.isVisible
        }
    }

    var isLocked: Bool {
        switch objectType {
        case .shape(let shape),
             .text(let shape),
             .image(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape),
             .guide(let shape):
            return shape.isLocked
        }
    }

    var shape: VectorShape {
        switch objectType {
        case .shape(let shape),
             .text(let shape),
             .image(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape),
             .guide(let shape):
            return shape
        }
    }
}

extension VectorObject: Codable {
    enum CodingKeys: String, CodingKey {
        case id, layerIndex, objectType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(layerIndex, forKey: .layerIndex)

        var objectContainer = container.nestedContainer(keyedBy: ObjectTypeCodingKeys.self, forKey: .objectType)

        // Encode both the type string and the shape
        switch objectType {
        case .shape(let shape):
            try objectContainer.encode("shape", forKey: .type)
            try objectContainer.encode(shape, forKey: .shape)
        case .text(let shape):
            try objectContainer.encode("text", forKey: .type)
            try objectContainer.encode(shape, forKey: .shape)
        case .image(let shape):
            try objectContainer.encode("image", forKey: .type)
            try objectContainer.encode(shape, forKey: .shape)
        case .warp(let shape):
            try objectContainer.encode("warp", forKey: .type)
            try objectContainer.encode(shape, forKey: .shape)
        case .group(let shape):
            try objectContainer.encode("group", forKey: .type)
            try objectContainer.encode(shape, forKey: .shape)
        case .clipGroup(let shape):
            try objectContainer.encode("clipGroup", forKey: .type)
            try objectContainer.encode(shape, forKey: .shape)
        case .clipMask(let shape):
            try objectContainer.encode("clipMask", forKey: .type)
            try objectContainer.encode(shape, forKey: .shape)
        case .guide(let shape):
            try objectContainer.encode("guide", forKey: .type)
            try objectContainer.encode(shape, forKey: .shape)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        layerIndex = try container.decode(Int.self, forKey: .layerIndex)

        let objectContainer = try container.nestedContainer(keyedBy: ObjectTypeCodingKeys.self, forKey: .objectType)
        var shape = try objectContainer.decode(VectorShape.self, forKey: .shape)

        // MIGRATION: Fix old text objects that have textPosition instead of transform
        // Keep textPosition intact - it's used by spatial index and hit testing
        if shape.typography != nil, let textPosition = shape.textPosition {
            if shape.transform.tx == 0 && shape.transform.ty == 0 {
                // Old format - copy textPosition to transform for compatibility
                var newTransform = shape.transform
                newTransform.tx = textPosition.x
                newTransform.ty = textPosition.y
                shape.transform = newTransform
                // DO NOT clear textPosition - spatial index needs it
            }
        }

        // Try to decode the explicit type first (for new files)
        if let typeString = try? objectContainer.decode(String.self, forKey: .type) {
            switch typeString {
            case "shape":
                objectType = .shape(shape)
            case "text":
                objectType = .text(shape)
            case "image":
                objectType = .image(shape)
            case "warp":
                objectType = .warp(shape)
            case "group":
                objectType = .group(shape)
            case "clipGroup":
                objectType = .clipGroup(shape)
            case "clipMask":
                objectType = .clipMask(shape)
            case "guide":
                objectType = .guide(shape)
            default:
                objectType = .shape(shape) // Fallback
            }
        } else {
            // Fallback for old files - infer from shape properties
            if shape.isGuide {
                objectType = .guide(shape)
            } else if shape.typography != nil {
                objectType = .text(shape)
            } else if shape.embeddedImageData != nil || shape.linkedImagePath != nil {
                objectType = .image(shape)
            } else if shape.isClippingPath {
                objectType = .clipMask(shape)
            } else if shape.isClippingGroup {
                objectType = .clipGroup(shape)
            } else if shape.isGroup && (!shape.memberIDs.isEmpty || !shape.groupedShapes.isEmpty) {
                objectType = .group(shape)
            } else if shape.isWarpObject {
                objectType = .warp(shape)
            } else {
                objectType = .shape(shape)
            }
        }
    }

    private enum ObjectTypeCodingKeys: String, CodingKey {
        case type, shape
    }
}
