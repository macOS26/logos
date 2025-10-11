import SwiftUI

extension FileOperations {


    static func importFromPDFData(_ data: Data) throws -> VectorDocument {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")

        do {
            try data.write(to: tempURL)
            let document = try importFromPDFSync(url: tempURL)

            try? FileManager.default.removeItem(at: tempURL)

            return document
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    static func importFromPDFSync(url: URL) throws -> VectorDocument {

        let semaphore = DispatchSemaphore(value: 0)
        var resultDocument: VectorDocument?
        var resultError: Error?

        Task {
            do {
                resultDocument = try await importFromPDF(url: url)
            } catch {
                resultError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = resultError {
            throw error
        }

        guard let document = resultDocument else {
            throw VectorImportError.parsingError("Failed to import PDF: Unknown error", line: nil)
        }

        return document
    }

    static func importFromPDF(url: URL) async throws -> VectorDocument {
        let result = await VectorImportManager.shared.importVectorFile(from: url)

        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown PDF import error"
            throw VectorImportError.parsingError("Failed to import PDF: \(errorMessage)", line: nil)
        }

        if let inkpenMetadata = result.metadata.inkpenMetadata {

            guard let inkpenData = Data(base64Encoded: inkpenMetadata) else {
                Log.error("❌ Failed to decode inkpen metadata from base64", category: .error)
                throw VectorImportError.parsingError("Invalid inkpen metadata encoding", line: nil)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let inkpenDocument = try decoder.decode(VectorDocument.self, from: inkpenData)

            return inkpenDocument
        }

        let document = VectorDocument()

        let pdfDocumentSize = result.metadata.documentSize
        let canvasWidth = pdfDocumentSize.width
        let canvasHeight = pdfDocumentSize.height

        document.settings.width = canvasWidth / 72.0
        document.settings.height = canvasHeight / 72.0
        document.settings.unit = .inches

        document.updateCanvasLayer()
        document.updatePasteboardLayer()

        for shape in result.shapes {
            var importedShape = shape

            importedShape.isLocked = false
            importedShape.isVisible = true

            if let imageData = importedShape.embeddedImageData {
                if let nsImage = NSImage(data: imageData) {
                    ImageContentRegistry.register(image: nsImage, for: importedShape.id)
                } else {
                    Log.error("PDF IMPORT: ❌ Failed to create NSImage from \(imageData.count) bytes of data", category: .error)
                    Log.error("❌ Could not create NSImage from embedded data for '\(importedShape.name)'", category: .error)
                }
            }

            document.addShapeToUnifiedSystem(importedShape, layerIndex: 2)
        }

        document.selectedLayerIndex = 2

        return document
    }
}
