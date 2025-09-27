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
            Log.info("🎭 VECTOROBJECT INIT DEBUG: Input shape '\(shape.name)' - isClippingPath: \(shape.isClippingPath), clippedByShapeID: \(shape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")", category: .debug)
        }
        
        self.id = shape.id
        self.orderID = orderID
        self.layerIndex = layerIndex
        self.objectType = .shape(shape)
        
        // DEBUG: Check if properties are preserved after storing in enum
        if case .shape(let storedShape) = self.objectType {
            if storedShape.isClippingPath || storedShape.clippedByShapeID != nil {
                Log.info("🎭 VECTOROBJECT INIT DEBUG: Stored shape '\(storedShape.name)' - isClippingPath: \(storedShape.isClippingPath), clippedByShapeID: \(storedShape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")", category: .debug)
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
        Log.info("🔍 DECODE DEBUG: Available keys in VectorObject container: \(container.allKeys.map { $0.stringValue })", category: .debug)

        id = try container.decode(UUID.self, forKey: .id)
        orderID = try container.decode(Int.self, forKey: .orderID)
        layerIndex = try container.decode(Int.self, forKey: .layerIndex)

        // Decode objectType with detailed error handling
        do {
            let objectContainer = try container.nestedContainer(keyedBy: ObjectTypeCodingKeys.self, forKey: .objectType)
            Log.info("🔍 DECODE DEBUG: Available keys in objectType container: \(objectContainer.allKeys.map { $0.stringValue })", category: .debug)

            // Try to decode shape with more detailed error catching
            do {
                let shape = try objectContainer.decode(VectorShape.self, forKey: .shape)
                objectType = .shape(shape)
                Log.info("✅ DECODE DEBUG: Successfully decoded VectorShape", category: .debug)
            } catch let shapeError {
                Log.error("❌ DECODE DEBUG: Failed to decode VectorShape - Error: \(shapeError)", category: .error)
                Log.error("❌ DECODE DEBUG: Error type: \(type(of: shapeError))", category: .error)
                if let decodingError = shapeError as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        Log.info("   Type mismatch: expected \(type), context: \(context)", category: .general)
                    case .valueNotFound(let type, let context):
                        Log.info("   Value not found: type \(type), context: \(context)", category: .general)
                    case .keyNotFound(let key, let context):
                        Log.info("   Key not found: \(key), context: \(context)", category: .general)
                    case .dataCorrupted(let context):
                        Log.info("   Data corrupted: \(context)", category: .general)
                    @unknown default:
                        Log.error("   Unknown decoding error", category: .error)
                    }
                }
                throw shapeError
            }
        } catch {
            Log.error("❌ DECODE DEBUG: Failed to get nested container for objectType - Error: \(error)", category: .error)
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
