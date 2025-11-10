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
        for obj in inkpenDocument.document.snapshot.objects.values {
            if case .shape(let shape) = obj.objectType {
                if ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: inkpenDocument.document) != nil {
                    imagesHydrated += 1
                }
            } else if case .image(let shape) = obj.objectType {
                if ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: inkpenDocument.document) != nil {
                    imagesHydrated += 1
                }
            }
        }

        if imagesHydrated > 0 {
            Log.fileOperation("  🖼️ Hydrated \(imagesHydrated) linked image(s) from \(baseDirectory.path)", level: .info)
        }
    }
}
