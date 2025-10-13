import SwiftUI
import AppKit

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

    @discardableResult
    static func hydrateImageIfAvailable(for shape: VectorShape) -> NSImage? {
        if let existing = queue.sync(execute: { storage[shape.id] }) {
            return existing
        }

        var loadedImage: NSImage? = nil

        if let data = shape.embeddedImageData, let image = NSImage(data: data) {
            loadedImage = image
        }
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
            var url: URL? = nil
            if path.hasPrefix("/") {
                url = URL(fileURLWithPath: path)
            } else if let base = baseDirectoryURL {
                url = base.appendingPathComponent(path)
            } else {
                let homeURL = FileManager.default.homeDirectoryForCurrentUser
                url = homeURL.appendingPathComponent(path)
                if let urlPath = url?.path, !FileManager.default.fileExists(atPath: urlPath) {
                    let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    url = docsURL?.appendingPathComponent(path)
                }
            }

            if let finalURL = url, let image = NSImage(contentsOf: finalURL) {
                loadedImage = image
            }
        }

        if let image = loadedImage {
            queue.async(flags: .barrier) {
                storage[shape.id] = image
            }
        }

        return loadedImage
    }

    static func setBaseDirectory(_ url: URL?) {
        queue.async(flags: .barrier) {
            baseDirectoryURL = url
        }
    }

    static func remove(for shapeID: UUID) {
        queue.async(flags: .barrier) {
            storage.removeValue(forKey: shapeID)
        }
    }

    static func cleanup(keepingShapes shapeIDs: Set<UUID>) {
        queue.async(flags: .barrier) {
            let keysToRemove = storage.keys.filter { !shapeIDs.contains($0) }
            for key in keysToRemove {
                storage.removeValue(forKey: key)
            }
        }
    }

    static func clearAll() {
        queue.async(flags: .barrier) {
            storage.removeAll()
        }
    }

    static func storageSize() -> Int {
        return queue.sync {
            storage.count
        }
    }
}
