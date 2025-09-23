//
//  ImageContentRegistry.swift
//  logos inkpen.io
//
//  Created for raster image content management.
//

import SwiftUI
import AppKit

/// Registry that stores raster image content keyed by `VectorShape.id`
/// This mirrors the SVG registry approach and keeps models lightweight.
enum ImageContentRegistry {
    private static var storage: [UUID: NSImage] = [:]
    private static var baseDirectoryURL: URL? = nil
    private static let queue = DispatchQueue(label: "com.inkpen.imageregistry", attributes: .concurrent)
    
    static func register(image: NSImage, for shapeID: UUID) {
        queue.async(flags: .barrier) {
            storage[shapeID] = image
        }
    }
    
    static func image(for shapeID: UUID) -> NSImage? {
        return queue.sync {
            storage[shapeID]
        }
    }
    
    static func containsImage(_ shape: VectorShape) -> Bool {
        return queue.sync {
            storage[shape.id] != nil
        }
    }
    
    /// Attempts to hydrate (load) the image content for a shape 
    /// using either embedded image data or a linked file path.
    /// Returns the hydrated image on success.
    @discardableResult
    static func hydrateImageIfAvailable(for shape: VectorShape) -> NSImage? {
        // Check if already loaded (thread-safe read)
        if let existing = queue.sync(execute: { storage[shape.id] }) {
            return existing
        }
        
        var loadedImage: NSImage? = nil
        
        // 1) Embedded data takes precedence
        if let data = shape.embeddedImageData, let image = NSImage(data: data) {
            loadedImage = image
        }
        // 2) Linked path fallback (supports security-scoped bookmark if provided)
        else if let bookmark = shape.linkedImageBookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                if let image = NSImage(contentsOf: url) {
                    loadedImage = image
                }
            }
        } else if let path = shape.linkedImagePath {
            // Support plain path or relative to baseDirectoryURL
            var url: URL? = nil
            if path.hasPrefix("/") {
                // Absolute path
                url = URL(fileURLWithPath: path)
            } else if let base = baseDirectoryURL {
                // Relative to base directory
                url = base.appendingPathComponent(path)
            } else {
                // Try as relative to home or Documents
                let homeURL = FileManager.default.homeDirectoryForCurrentUser
                url = homeURL.appendingPathComponent(path)
                if !FileManager.default.fileExists(atPath: url!.path) {
                    let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    url = docsURL?.appendingPathComponent(path)
                }
            }
            
            if let finalURL = url, let image = NSImage(contentsOf: finalURL) {
                loadedImage = image
            }
        }
        
        // Store the loaded image thread-safely
        if let image = loadedImage {
            queue.async(flags: .barrier) {
                storage[shape.id] = image
            }
        }
        
        return loadedImage
    }
    
    /// Sets a base directory URL for resolving relative image paths
    static func setBaseDirectory(_ url: URL?) {
        queue.async(flags: .barrier) {
            baseDirectoryURL = url
        }
    }
}
