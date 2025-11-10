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
