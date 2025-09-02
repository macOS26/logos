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
