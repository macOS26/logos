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
    private static var baseDirectoryURL: URL? = nil
    
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
    
    // MARK: - Base Directory for Linked Assets
    static func setBaseDirectoryURL(_ url: URL?) {
        baseDirectoryURL = url
    }
    
    // MARK: - Hydration from persisted fields
    /// Attempt to load and register a raster image for the given shape
    /// using either embedded image data or a linked file path.
    /// Returns the hydrated image on success.
    @discardableResult
    static func hydrateImageIfAvailable(for shape: VectorShape) -> NSImage? {
        if let existing = storage[shape.id] { return existing }
        
        // 1) Embedded data takes precedence
        if let data = shape.embeddedImageData, let image = NSImage(data: data) {
            storage[shape.id] = image
            return image
        }
        
        // 2) Linked path fallback (supports security-scoped bookmark if provided)
        if let bookmark = shape.linkedImageBookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                if let image = NSImage(contentsOf: url) {
                    storage[shape.id] = image
                    return image
                }
            }
        }

        // 3) Plain file path fallback
        if let path = shape.linkedImagePath, !path.isEmpty {
            // Resolve relative paths against the current document directory
            let url: URL
            if path.hasPrefix("/") || path.hasPrefix("~/") {
                url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
            } else if let base = baseDirectoryURL {
                url = base.appendingPathComponent(path)
            } else {
                url = URL(fileURLWithPath: path)
            }
            if let image = NSImage(contentsOf: url) {
                storage[shape.id] = image
                return image
            }
        }
        
        return nil
    }
}


