
import SwiftUI

struct VectorObject: Identifiable, Hashable {
    let id: UUID
    let orderID: Int
    let layerIndex: Int
    let objectType: ObjectType

    enum ObjectType: Hashable {
        case shape(VectorShape)
    }

    init(shape: VectorShape, layerIndex: Int, orderID: Int) {

        self.id = shape.id
        self.orderID = orderID
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
        case id, orderID, layerIndex, objectType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderID, forKey: .orderID)
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
        orderID = try container.decode(Int.self, forKey: .orderID)
        layerIndex = try container.decode(Int.self, forKey: .layerIndex)

        do {
            let objectContainer = try container.nestedContainer(keyedBy: ObjectTypeCodingKeys.self, forKey: .objectType)

            do {
                let shape = try objectContainer.decode(VectorShape.self, forKey: .shape)
                objectType = .shape(shape)
            } catch let shapeError {
                Log.error("❌ Failed to decode VectorShape - Error: \(shapeError)", category: .error)
                if let decodingError = shapeError as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(_, _):
                        break
                    case .valueNotFound(_, _):
                        break
                    case .keyNotFound(_, _):
                        break
                    case .dataCorrupted(_):
                        break
                    @unknown default:
                        Log.error("   Unknown decoding error", category: .error)
                    }
                }
                throw shapeError
            }
        } catch {
            Log.error("❌ Failed to get nested container for objectType - Error: \(error)", category: .error)
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unable to decode VectorObject.objectType - \(error.localizedDescription)"
            ))
        }
    }

    private enum ObjectTypeCodingKeys: String, CodingKey {
        case shape
    }
}