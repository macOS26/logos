//
//  ImageContentRegistry.swift
//  logos inkpen.io
//
//  Created for raster image content management.
//

import Foundation
import AppKit

/// Registry that stores raster image content keyed by `VectorShape.id`
/// This mirrors the SVG registry approach and keeps models lightweight.
enum ImageContentRegistry {
    private static var storage: [UUID: NSImage] = [:]
    
    static func register(image: NSImage, for shapeID: UUID) {
        storage[shapeID] = image
    }
    
    static func image(for shapeID: UUID) -> NSImage? {
        return storage[shapeID]
    }
    
    static func containsImage(_ shape: VectorShape) -> Bool {
        return storage[shape.id] != nil
    }
    
    static func remove(for shapeID: UUID) {
        storage.removeValue(forKey: shapeID)
    }
}


