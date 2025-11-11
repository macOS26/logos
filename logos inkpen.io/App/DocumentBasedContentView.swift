import SwiftUI

struct DocumentBasedContentView: View {
    @Binding var inkpenDocument: InkpenDocument
    let fileURL: URL?
    @State private var hasHydratedImages = false

    var body: some View {
        DocumentBasedMainView(document: inkpenDocument.document, fileURL: fileURL)
            .onAppear {
                // Hydrate linked images on first appear
                if !hasHydratedImages, let fileURL = fileURL {
                    hydrateLinkedImages(from: fileURL)
                    hasHydratedImages = true
                }
            }
    }

    private func resolveAndCacheLinkedImage(shape: VectorShape, document: VectorDocument, quality: Double) -> CGImage? {
        guard let linkedPath = shape.linkedImagePath else { return nil }

        if let bookmarkData = shape.linkedImageBookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                return ImageTileCache.shared.getSourceImage(from: url, quality: quality)
            }
        }

        let absoluteURL = URL(fileURLWithPath: linkedPath)
        if let image = ImageTileCache.shared.getSourceImage(from: absoluteURL, quality: quality) {
            return image
        }

        if let docURL = inkpenDocument.document.baseDirectoryURL {
            let docDir = docURL.deletingLastPathComponent()
            let relativeURL = docDir.appendingPathComponent(linkedPath)
            if let image = ImageTileCache.shared.getSourceImage(from: relativeURL, quality: quality) {
                return image
            }

            let filename = URL(fileURLWithPath: linkedPath).lastPathComponent
            let sameDir = docDir.appendingPathComponent(filename)
            if let image = ImageTileCache.shared.getSourceImage(from: sameDir, quality: quality) {
                return image
            }
        }

        return nil
    }

    private func hydrateLinkedImages(from sourceURL: URL) {
        let baseDirectory = sourceURL.deletingLastPathComponent()
        ImageContentRegistry.setBaseDirectory(baseDirectory, for: inkpenDocument.document)

        var imagesHydrated = 0
        var imagesMissing = 0
        var missingPaths: [String] = []

        for obj in inkpenDocument.document.snapshot.objects.values {
            var shape: VectorShape? = nil

            if case .shape(let s) = obj.objectType {
                shape = s
            } else if case .image(let s) = obj.objectType {
                shape = s
            }

            if let shape = shape {
                // Check if this shape has image data
                let hasImageData = shape.embeddedImageData != nil ||
                                   shape.linkedImagePath != nil ||
                                   shape.linkedImageBookmarkData != nil

                if hasImageData {
                    if let _ = ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: inkpenDocument.document) {
                        imagesHydrated += 1

                        // Cache CGImage in shape for rendering performance
                        let quality = ApplicationSettings.shared.imagePreviewQuality
                        if let imageData = shape.embeddedImageData {
                            if let cgImage = ImageTileCache.shared.getSourceImage(from: imageData, quality: quality) {
                                var updatedShape = shape
                                updatedShape.cachedCGImage = cgImage
                                if case .image(_) = obj.objectType {
                                    inkpenDocument.document.snapshot.objects[obj.id] = VectorObject(id: obj.id, layerIndex: obj.layerIndex, objectType: .image(updatedShape))
                                } else if case .shape(_) = obj.objectType {
                                    inkpenDocument.document.snapshot.objects[obj.id] = VectorObject(id: obj.id, layerIndex: obj.layerIndex, objectType: .shape(updatedShape))
                                }
                            }
                        } else if shape.linkedImagePath != nil {
                            // For linked images, cache after resolving path
                            if let cgImage = resolveAndCacheLinkedImage(shape: shape, document: inkpenDocument.document, quality: quality) {
                                var updatedShape = shape
                                updatedShape.cachedCGImage = cgImage
                                if case .image(_) = obj.objectType {
                                    inkpenDocument.document.snapshot.objects[obj.id] = VectorObject(id: obj.id, layerIndex: obj.layerIndex, objectType: .image(updatedShape))
                                } else if case .shape(_) = obj.objectType {
                                    inkpenDocument.document.snapshot.objects[obj.id] = VectorObject(id: obj.id, layerIndex: obj.layerIndex, objectType: .shape(updatedShape))
                                }
                            }
                        }
                    } else {
                        imagesMissing += 1
                        if let path = shape.linkedImagePath {
                            missingPaths.append(path)
                            Log.fileOperation("  ⚠️ Missing linked image: \(path)", level: .warning)
                        } else if shape.linkedImageBookmarkData != nil {
                            missingPaths.append("<bookmark data>")
                            Log.fileOperation("  ⚠️ Missing linked image (from bookmark)", level: .warning)
                        } else {
                            Log.fileOperation("  ⚠️ Failed to load embedded image for shape: \(shape.id)", level: .warning)
                        }
                    }
                }
            }
        }

        if imagesHydrated > 0 {
            Log.fileOperation("  🖼️ Hydrated \(imagesHydrated) linked image(s) from \(baseDirectory.path)", level: .info)
        }

        if imagesMissing > 0 {
            Log.fileOperation("  ❌ Failed to load \(imagesMissing) image(s)", level: .error)
            Log.fileOperation("  Missing paths: \(missingPaths.joined(separator: ", "))", level: .error)
        }
    }
}
