import SwiftUI

struct DocumentBasedContentView: View {
    @Binding var inkpenDocument: InkpenDocument
    let fileURL: URL?
    @State private var hasHydratedImages = false
    @AppStorage("imagePreviewQuality") var imagePreviewQuality: Double = 1.0
    @AppStorage("imageTileSize") var imageTileSize: Int = 512
    @AppStorage("imageInterpolationQuality") var imageInterpolationQuality: Int = 1

    var body: some View {
        DocumentBasedMainView(document: inkpenDocument.document, fileURL: fileURL, imagePreviewQuality: $imagePreviewQuality, imageTileSize: $imageTileSize, imageInterpolationQuality: $imageInterpolationQuality)
            .onAppear {
                MemoryDiag.report("DocumentBasedContentView.onAppear (before hydrate)", document: inkpenDocument.document)
                // Hydrate linked images on first appear
                if !hasHydratedImages, let fileURL = fileURL {
                    hydrateLinkedImages(from: fileURL)
                    hasHydratedImages = true
                }
                MemoryDiag.report("DocumentBasedContentView.onAppear (after hydrate)", document: inkpenDocument.document)
                MemoryDiag.measureObjectSizes(inkpenDocument.document)
            }
            .onChange(of: imagePreviewQuality) { _, _ in
                // Clear image caches when quality changes
                ImageContentRegistry.clearAll(in: inkpenDocument.document)
                MetalImageTileRenderer.shared?.clearCache()
            }
            .onChange(of: imageTileSize) { _, _ in
                // Clear image caches when tile size changes
                ImageContentRegistry.clearAll(in: inkpenDocument.document)
                MetalImageTileRenderer.shared?.clearCache()
            }
    }


    private func hydrateLinkedImages(from sourceURL: URL) {
        let baseDirectory = sourceURL.deletingLastPathComponent()
        ImageContentRegistry.setBaseDirectory(baseDirectory, for: inkpenDocument.document)

        var imagesHydrated = 0
        var imagesMissing = 0
        var imagesDeleted = 0
        var missingPaths: [String] = []
        var shapesToDelete: [UUID] = []

        for (id, obj) in inkpenDocument.document.snapshot.objects {
            var shape: VectorShape? = nil
            if case .shape(let s) = obj.objectType { shape = s }
            else if case .image(let s) = obj.objectType { shape = s }

            guard let shape = shape else { continue }
            let hasImageData = shape.embeddedImageData != nil ||
                               shape.linkedImagePath != nil ||
                               shape.linkedImageBookmarkData != nil
            guard hasImageData else { continue }

            // Drop shapes whose embedded payload is XML/SVG text or obviously too small to be a raster.
            if let data = shape.embeddedImageData,
               shape.linkedImagePath == nil,
               shape.linkedImageBookmarkData == nil,
               (data.count < 16 || SVGParser.looksLikeXML(data)) {
                shapesToDelete.append(id)
                continue
            }

            if ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: inkpenDocument.document) != nil {
                imagesHydrated += 1
                continue
            }

            if let path = shape.linkedImagePath {
                imagesMissing += 1
                missingPaths.append(path)
                Log.fileOperation("  ⚠️ Missing linked image: \(path)", level: .warning)
            } else if shape.linkedImageBookmarkData != nil {
                imagesMissing += 1
                missingPaths.append("<bookmark data>")
                Log.fileOperation("  ⚠️ Missing linked image (from bookmark)", level: .warning)
            } else {
                shapesToDelete.append(id)
            }
        }

        for id in shapesToDelete {
            inkpenDocument.document.removeShapeFromUnifiedSystem(id: id)
            imagesDeleted += 1
        }

        if imagesHydrated > 0 {
            Log.fileOperation("  🖼️ Hydrated \(imagesHydrated) linked image(s) from \(baseDirectory.path)", level: .info)
        }
        if imagesDeleted > 0 {
            Log.fileOperation("  🗑️ Deleted \(imagesDeleted) broken/empty image shape(s)", level: .info)
        }
        if imagesMissing > 0 {
            Log.fileOperation("  ❌ Missing linked files: \(imagesMissing)", level: .error)
            Log.fileOperation("  Paths: \(missingPaths.joined(separator: ", "))", level: .error)
        }
    }
}
