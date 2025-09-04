//
//  VectorObject.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/24/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Unified Object System
/// Represents any object that can be placed on a layer with proper ordering
struct VectorObject: Identifiable, Codable, Hashable {
    let id: UUID
    let orderID: Int // Unique ordering within layer - no two objects on same layer can have same orderID
    let layerIndex: Int // Which layer this object belongs to
    let objectType: ObjectType
    
    enum ObjectType: Codable, Hashable {
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
