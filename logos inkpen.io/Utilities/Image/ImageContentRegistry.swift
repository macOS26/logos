import SwiftUI
import AppKit

enum ImageContentRegistry {
    static func register(image: NSImage, for shapeID: UUID, in document: VectorDocument) {
        document.imageStorage[shapeID] = image
    }

    static func image(for shapeID: UUID, in document: VectorDocument) -> NSImage? {
        return document.imageStorage[shapeID]
    }

    static func containsImage(_ shape: VectorShape, in document: VectorDocument) -> Bool {
        return document.imageStorage[shape.id] != nil
    }

    @discardableResult
    static func hydrateImageIfAvailable(for shape: VectorShape, in document: VectorDocument) -> NSImage? {
        if let existing = document.imageStorage[shape.id] {
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
            } else if let base = document.baseDirectoryURL {
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
            document.imageStorage[shape.id] = image
        }

        return loadedImage
    }

    static func setBaseDirectory(_ url: URL?, for document: VectorDocument) {
        document.baseDirectoryURL = url
    }

    static func remove(for shapeID: UUID, in document: VectorDocument) {
        document.imageStorage.removeValue(forKey: shapeID)
    }

    static func cleanup(keepingShapes shapeIDs: Set<UUID>, in document: VectorDocument) {
        let keysToRemove = document.imageStorage.keys.filter { !shapeIDs.contains($0) }
        for key in keysToRemove {
            document.imageStorage.removeValue(forKey: key)
        }
    }

    static func clearAll(in document: VectorDocument) {
        document.imageStorage.removeAll()
    }

    static func storageSize(in document: VectorDocument) -> Int {
        return document.imageStorage.count
    }
}
