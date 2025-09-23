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
            print("🎭 VECTOROBJECT INIT DEBUG: Input shape '\(shape.name)' - isClippingPath: \(shape.isClippingPath), clippedByShapeID: \(shape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")")
        }
        
        self.id = shape.id
        self.orderID = orderID
        self.layerIndex = layerIndex
        self.objectType = .shape(shape)
        
        // DEBUG: Check if properties are preserved after storing in enum
        if case .shape(let storedShape) = self.objectType {
            if storedShape.isClippingPath || storedShape.clippedByShapeID != nil {
                print("🎭 VECTOROBJECT INIT DEBUG: Stored shape '\(storedShape.name)' - isClippingPath: \(storedShape.isClippingPath), clippedByShapeID: \(storedShape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")")
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

        // Debug: Print all keys available
        print("🔍 DECODE DEBUG: Available keys in VectorObject container: \(container.allKeys.map { $0.stringValue })")

        id = try container.decode(UUID.self, forKey: .id)
        orderID = try container.decode(Int.self, forKey: .orderID)
        layerIndex = try container.decode(Int.self, forKey: .layerIndex)

        // Decode objectType with detailed error handling
        do {
            let objectContainer = try container.nestedContainer(keyedBy: ObjectTypeCodingKeys.self, forKey: .objectType)
            print("🔍 DECODE DEBUG: Available keys in objectType container: \(objectContainer.allKeys.map { $0.stringValue })")

            // Try to decode shape with more detailed error catching
            do {
                let shape = try objectContainer.decode(VectorShape.self, forKey: .shape)
                objectType = .shape(shape)
                print("✅ DECODE DEBUG: Successfully decoded VectorShape")
            } catch let shapeError {
                print("❌ DECODE DEBUG: Failed to decode VectorShape - Error: \(shapeError)")
                print("❌ DECODE DEBUG: Error type: \(type(of: shapeError))")
                if let decodingError = shapeError as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch: expected \(type), context: \(context)")
                    case .valueNotFound(let type, let context):
                        print("   Value not found: type \(type), context: \(context)")
                    case .keyNotFound(let key, let context):
                        print("   Key not found: \(key), context: \(context)")
                    case .dataCorrupted(let context):
                        print("   Data corrupted: \(context)")
                    @unknown default:
                        print("   Unknown decoding error")
                    }
                }
                throw shapeError
            }
        } catch {
            print("❌ DECODE DEBUG: Failed to get nested container for objectType - Error: \(error)")
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
