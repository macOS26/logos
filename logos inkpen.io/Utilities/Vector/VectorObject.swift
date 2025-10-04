//
//  VectorObject.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/24/25.
//

import SwiftUI

// MARK: - Unified Object System
/// Represents any object that can be placed on a layer with proper ordering
struct VectorObject: Identifiable, Hashable {
    let id: UUID
    let orderID: Int // Unique ordering within layer - no two objects on same layer can have same orderID
    let layerIndex: Int // Which layer this object belongs to
    let objectType: ObjectType
    
    enum ObjectType: Hashable {
        case shape(VectorShape)
    }
    
    init(shape: VectorShape, layerIndex: Int, orderID: Int) {
        // DEBUG: Log clipping properties during VectorObject creation
        if shape.isClippingPath || shape.clippedByShapeID != nil {
        }
        
        self.id = shape.id
        self.orderID = orderID
        self.layerIndex = layerIndex
        self.objectType = .shape(shape)
        
        // DEBUG: Check if properties are preserved after storing in enum
        if case .shape(let storedShape) = self.objectType {
            if storedShape.isClippingPath || storedShape.clippedByShapeID != nil {
            }
        }
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

// MARK: - VectorObject Codable Implementation
extension VectorObject: Codable {
    enum CodingKeys: String, CodingKey {
        case id, orderID, layerIndex, objectType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderID, forKey: .orderID)
        try container.encode(layerIndex, forKey: .layerIndex)

        // Encode objectType without wrapper
        var objectContainer = container.nestedContainer(keyedBy: ObjectTypeCodingKeys.self, forKey: .objectType)
        switch objectType {
        case .shape(let shape):
            try objectContainer.encode(shape, forKey: .shape)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Removed noisy debug logs that were triggered during normal undo/redo operations
        
        id = try container.decode(UUID.self, forKey: .id)
        orderID = try container.decode(Int.self, forKey: .orderID)
        layerIndex = try container.decode(Int.self, forKey: .layerIndex)

        // Decode objectType with detailed error handling
        do {
            let objectContainer = try container.nestedContainer(keyedBy: ObjectTypeCodingKeys.self, forKey: .objectType)
            
            // Try to decode shape with more detailed error catching
            do {
                let shape = try objectContainer.decode(VectorShape.self, forKey: .shape)
                objectType = .shape(shape)
            } catch let shapeError {
                // Only log actual errors, not normal decode operations
                // Log.error("❌ Failed to decode VectorShape - Error: \(shapeError)", category: .error)
                if let decodingError = shapeError as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        Log.error("   Type mismatch: expected \(type), context: \(context)", category: .general)
                    case .valueNotFound(let type, let context):
                        Log.error("   Value not found: type \(type), context: \(context)", category: .general)
                    case .keyNotFound(let key, let context):
                        Log.error("   Key not found: \(key), context: \(context)", category: .general)
                    case .dataCorrupted(let context):
                        Log.error("   Data corrupted: \(context)", category: .general)
                    @unknown default:
                        Log.error("   Unknown decoding error", category: .error)
                    }
                }
                throw shapeError
            }
        } catch {
            // Log.error("❌ Failed to get nested container for objectType - Error: \(error)", category: .error)
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
