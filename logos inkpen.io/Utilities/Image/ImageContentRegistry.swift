import SwiftUI
import AppKit
import ImageIO

enum ImageContentRegistry {
    static func register(image: CGImage, for shapeID: UUID, in document: VectorDocument) {
        document.imageStorage[shapeID] = image
    }

    static func image(for shapeID: UUID, in document: VectorDocument) -> CGImage? {
        return document.imageStorage[shapeID]
    }

    static func containsImage(_ shape: VectorShape, in document: VectorDocument) -> Bool {
        return document.imageStorage[shape.id] != nil
    }

    @discardableResult
    static func hydrateImageIfAvailable(for shape: VectorShape, in document: VectorDocument) -> CGImage? {
        if let existing = document.imageStorage[shape.id] {
            return existing
        }

        var loadedCGImage: CGImage? = nil

        // Try embedded image first
        if let data = shape.embeddedImageData,
           let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            loadedCGImage = cgImage
            print("✅ Loaded embedded image for shape: \(shape.id)")
        }
        // ONLY use bookmark for linked images - no fallback file access
        else if let bookmark = shape.linkedImageBookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if isStale {
                    print("⚠️ [Registry] Bookmark is stale for: \(url.path)")
                }
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                    loadedCGImage = cgImage
                    print("✅ [Registry] Loaded linked image via bookmark: \(url.path)")
                } else {
                    print("❌ [Registry] Failed to create CGImage from: \(url.path)")
                }
            } else {
                print("❌ [Registry] Failed to resolve bookmark for shape: \(shape.id)")
            }
        } else if shape.linkedImagePath != nil {
            print("❌ [Registry] Shape has linkedImagePath but NO bookmark: \(shape.linkedImagePath!)")
        }

        if let cgImage = loadedCGImage {
            document.imageStorage[shape.id] = cgImage
            return cgImage
        }

        return nil
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
