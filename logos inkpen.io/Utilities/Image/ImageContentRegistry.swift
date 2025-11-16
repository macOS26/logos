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

        if let data = shape.embeddedImageData,
           let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            loadedCGImage = cgImage
        }
        else if let bookmark = shape.linkedImageBookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                    loadedCGImage = cgImage
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

            if let finalURL = url,
               let imageSource = CGImageSourceCreateWithURL(finalURL as CFURL, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                loadedCGImage = cgImage
            }
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
