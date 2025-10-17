import SwiftUI

struct VectorObject: Identifiable, Hashable {
    let id: UUID
    let layerIndex: Int
    let objectType: ObjectType

    enum ObjectType: Hashable {
        case shape(VectorShape)
        case text(VectorShape)
        case warp(VectorShape)
        case group(VectorShape)
        case clipGroup(VectorShape)
        case clipMask(VectorShape)
    }

    init(shape: VectorShape, layerIndex: Int) {
        self.id = shape.id
        self.layerIndex = layerIndex

        if shape.typography != nil {
            self.objectType = .text(shape)
        } else if shape.isClippingPath {
            self.objectType = .clipMask(shape)
        } else if shape.isClippingGroup {
            self.objectType = .clipGroup(shape)
        } else if shape.isGroup && !shape.groupedShapes.isEmpty {
            self.objectType = .group(shape)
        } else if shape.isWarpObject {
            self.objectType = .warp(shape)
        } else {
            self.objectType = .shape(shape)
        }
    }

    var isVisible: Bool {
        switch objectType {
        case .shape(let shape),
             .text(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
            return shape.isVisible
        }
    }

    var isLocked: Bool {
        switch objectType {
        case .shape(let shape),
             .text(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
            return shape.isLocked
        }
    }

    var shape: VectorShape {
        switch objectType {
        case .shape(let shape),
             .text(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
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
        switch objectType {
        case .shape(let shape),
             .text(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
            try objectContainer.encode(shape, forKey: .shape)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        layerIndex = try container.decode(Int.self, forKey: .layerIndex)

        let objectContainer = try container.nestedContainer(keyedBy: ObjectTypeCodingKeys.self, forKey: .objectType)
        let shape = try objectContainer.decode(VectorShape.self, forKey: .shape)

        if shape.typography != nil {
            objectType = .text(shape)
        } else if shape.isClippingPath {
            objectType = .clipMask(shape)
        } else if shape.isClippingGroup {
            objectType = .clipGroup(shape)
        } else if shape.isGroup && !shape.groupedShapes.isEmpty {
            objectType = .group(shape)
        } else if shape.isWarpObject {
            objectType = .warp(shape)
        } else {
            objectType = .shape(shape)
        }
    }

    private enum ObjectTypeCodingKeys: String, CodingKey {
        case shape
    }
}
