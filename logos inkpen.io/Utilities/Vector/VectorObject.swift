import SwiftUI

struct VectorObject: Identifiable, Hashable {
    let id: UUID
    let layerIndex: Int
    let objectType: ObjectType

    enum ObjectType: Hashable {
        case shape(VectorShape)
    }

    init(shape: VectorShape, layerIndex: Int) {
        self.id = shape.id
        self.layerIndex = layerIndex
        self.objectType = .shape(shape)
    }

    var isVisible: Bool {
        switch objectType {
        case .shape(let shape):
            return shape.isVisible
        }
    }

    var isLocked: Bool {
        switch objectType {
        case .shape(let shape):
            return shape.isLocked
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
        case .shape(let shape):
            try objectContainer.encode(shape, forKey: .shape)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        layerIndex = try container.decode(Int.self, forKey: .layerIndex)

        let objectContainer = try container.nestedContainer(keyedBy: ObjectTypeCodingKeys.self, forKey: .objectType)
        let shape = try objectContainer.decode(VectorShape.self, forKey: .shape)
        objectType = .shape(shape)
    }

    private enum ObjectTypeCodingKeys: String, CodingKey {
        case shape
    }
}
