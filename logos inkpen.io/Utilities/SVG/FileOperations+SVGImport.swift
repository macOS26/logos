import SwiftUI

extension FileOperations {
    static func importFromSVGData(_ data: Data) throws -> VectorDocument {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).svg")
        try data.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let document = try runBlocking {
            try await openSVGFile(url: tempURL)
        }

        return document
    }

    private static func runBlocking<T>(_ asyncWork: @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>?

        Task {
            do {
                let value = try await asyncWork()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }

        semaphore.wait()

        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            throw VectorImportError.parsingError("Failed to import SVG", line: nil)
        }
    }

    @MainActor
    static func openSVGFile(url: URL) async throws -> VectorDocument {

        let document = VectorDocument(settings: DocumentSettings())
        // Keep only Canvas and Pasteboard background objects
        let objectsToKeep = document.snapshot.objects.filter { (_, obj) in
            if case .shape(let shape) = obj.objectType {
                return shape.name == "Canvas Background" || shape.name == "Pasteboard Background"
            }
            return false
        }
        document.snapshot.objects = objectsToKeep

        let result = await VectorImportManager.shared.importSVGWithExtremeValueHandling(from: url)

        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown SVG import error"
            throw VectorImportError.parsingError("Failed to import SVG: \(errorMessage)", line: nil)
        }

        if let inkpenMetadata = result.metadata.inkpenMetadata {

            guard let inkpenData = Data(base64Encoded: inkpenMetadata) else {
                Log.error("❌ Failed to decode inkpen metadata from base64", category: .error)
                throw VectorImportError.parsingError("Invalid inkpen metadata encoding", line: nil)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Try to decode as current format first
            if let inkpenDocument = try? decoder.decode(VectorDocument.self, from: inkpenData) {
                // Log version for migration tracking
                Log.fileOperation("📦 Opened inkpen document from SVG, version: \(inkpenDocument.snapshot.formatVersion)", level: .info)

                // Remove legacy background objects
                FileOperations.removeLegacyBackgroundObjects(from: inkpenDocument)

                return inkpenDocument
            }

            // Fallback: Try migration from legacy format
            Log.fileOperation("⚠️ Current format failed, attempting legacy migration from SVG...", level: .warning)
            if let migratedDocument = InkpenMigrator.migrateLegacyDocument(from: inkpenData) {
                return migratedDocument
            }

            Log.error("❌ Failed to decode inkpen metadata from SVG", category: .error)
            throw VectorImportError.parsingError("Invalid inkpen metadata in SVG", line: nil)
        }

        let metadata = result.metadata
        let docSize = metadata.documentSize

        if let viewBoxSize = metadata.viewBoxSize {
            let widthRatio = docSize.width / viewBoxSize.width
            let heightRatio = docSize.height / viewBoxSize.height

            if abs(widthRatio - (96.0/72.0)) < 0.1 && abs(heightRatio - (96.0/72.0)) < 0.1 {

                document.settings.width = viewBoxSize.width / 72.0
                document.settings.height = viewBoxSize.height / 72.0
            } else {
                document.settings.width = docSize.width / 72.0
                document.settings.height = docSize.height / 72.0
            }
        } else {
            document.settings.width = docSize.width / 72.0
            document.settings.height = docSize.height / 72.0
        }

        let importedLayer = Layer(
            id: UUID(),
            name: "Imported SVG",
            objectIDs: [],
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            color: .green
        )

        if document.snapshot.layers.count < 3 {
            document.snapshot.layers.append(importedLayer)
        } else {
            document.snapshot.layers[2] = importedLayer
        }

        var clippingMasks: [UUID: (mask: VectorShape, clippedShapes: [VectorShape])] = [:]
        var standaloneShapes: [VectorShape] = []

        for shape in result.shapes {
            autoreleasepool {
                if shape.isClippingPath {
                    if clippingMasks[shape.id] == nil {
                        clippingMasks[shape.id] = (mask: shape, clippedShapes: [])
                    } else {
                        clippingMasks[shape.id]?.mask = shape
                    }
                } else if let clipId = shape.clippedByShapeID {
                    if clippingMasks[clipId] == nil {
                        clippingMasks[clipId] = (mask: VectorShape(name: "Placeholder", path: VectorPath(elements: [])), clippedShapes: [shape])
                    } else {
                        clippingMasks[clipId]?.clippedShapes.append(shape)
                    }
                } else {
                    let shouldSkip: Bool = {
                        let tempObject = VectorObject(shape: shape, layerIndex: 0)
                        switch tempObject.objectType {
                        case .text:
                            let textContent = shape.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            return textContent.isEmpty
                        case .shape, .image, .warp, .group, .clipGroup, .clipMask, .guide:
                            return shape.path.elements.isEmpty
                        }
                    }()

                    if !shouldSkip {
                        standaloneShapes.append(shape)
                    }
                }
            }
        }

        for shape in standaloneShapes {
            autoreleasepool {

                document.addShapeToUnifiedSystem(shape, layerIndex: 2)
            }
        }

        for (_, maskGroup) in clippingMasks {
            autoreleasepool {
                guard maskGroup.mask.name != "Placeholder" else { return }

                for clippedShape in maskGroup.clippedShapes {

                    document.addShapeToUnifiedSystem(clippedShape, layerIndex: 2)
                }

                document.addShapeToUnifiedSystem(maskGroup.mask, layerIndex: 2)
            }
        }

        document.selectedLayerIndex = 3

        // Remove legacy background objects from imported SVG
        FileOperations.removeLegacyBackgroundObjects(from: document)

        return document
    }
}
