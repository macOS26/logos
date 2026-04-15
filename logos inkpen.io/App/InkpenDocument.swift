import SwiftUI
import UniformTypeIdentifiers

struct InkpenDocument: FileDocument {
    var document: VectorDocument

    static var readableContentTypes: [UTType] { [.inkpen, .svg, .pdf, .freehandDocument] }
    static var writableContentTypes: [UTType] { [.inkpen, .svg, .pdf] }

    private static let freehandExtensions: Set<String> = [
        "fh", "fh1", "fh2", "fh3", "fh4", "fh5", "fh6", "fh7", "fh8", "fh9",
        "fh10", "fh11", "fhmx", "ft11", "ftmx", "eps"
    ]

    init() {
        self.document = VectorDocument()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            Log.error("❌ InkpenDocument: regularFileContents is nil for \(configuration.file.preferredFilename ?? "?")", category: .error)
            throw CocoaError(.fileReadCorruptFile)
        }

        let fileExtension = configuration.file.preferredFilename?.components(separatedBy: ".").last?.lowercased()
        let contentType = configuration.contentType
        Log.info("📂 InkpenDocument.init: filename=\(configuration.file.preferredFilename ?? "?") ext=\(fileExtension ?? "nil") contentType=\(contentType.identifier) bytes=\(data.count)", category: .general)

        /* File → Duplicate routes through fileWrapper (which writes inkpen JSON
           for an FH-opened doc) then back into init with contentType still set
           to .freehandDocument. Don't trust contentType — sniff the actual
           bytes for FreeHand's "AGD…" or "FH3…" magic. Anything else with an
           FH extension falls through to JSON/inkpen loading. */
        let hasFHMagic: Bool = {
            guard data.count >= 4 else { return false }
            let b0 = data[0], b1 = data[1], b2 = data[2]
            // "AGD" for FH5+, "FH3" for FH3, "FHD2" for FH2
            if b0 == UInt8(ascii: "A"), b1 == UInt8(ascii: "G"), b2 == UInt8(ascii: "D") { return true }
            if b0 == UInt8(ascii: "F"), b1 == UInt8(ascii: "H"), b2 == UInt8(ascii: "3") { return true }
            if b0 == UInt8(ascii: "F"), b1 == UInt8(ascii: "H"), b2 == UInt8(ascii: "D") { return true }
            // EPS (PostScript) exported from FreeHand
            if b0 == UInt8(ascii: "%"), b1 == UInt8(ascii: "!"), b2 == UInt8(ascii: "P") { return true }
            // 0x1c IPTC wrapper used by some FH versions (e.g. FH10)
            if b0 == 0x1c { return true }
            return false
        }()

        let extSaysFreehand: Bool = {
            if let ext = fileExtension, Self.freehandExtensions.contains(ext) { return true }
            if contentType == .freehandDocument { return true }
            if contentType.conforms(to: .freehandDocument) { return true }
            if contentType.identifier.contains("freehand") { return true }
            return false
        }()

        // Only take the FH path if BOTH the extension claims FH AND the bytes
        // actually look like a FreeHand file. Duplicate's JSON roundtrip keeps
        // the FH extension but the data is JSON — sniff prevents false parse.
        let isFreehand = extSaysFreehand && hasFHMagic

        if fileExtension == "svg" {
            do {
                self.document = try FileOperations.importFromSVGData(data)

                var minX: CGFloat = .infinity
                var minY: CGFloat = .infinity

                for obj in self.document.snapshot.objects.values {
                    switch obj.objectType {
                    case .text(let shape),
                         .shape(let shape),
                         .image(let shape),
                         .warp(let shape),
                         .group(let shape),
                         .clipGroup(let shape),
                         .clipMask(let shape),
                         .guide(let shape):
                        if let textPos = shape.textPosition {
                            minX = min(minX, textPos.x)
                            minY = min(minY, textPos.y)
                        } else {
                            minX = min(minX, shape.bounds.minX)
                            minY = min(minY, shape.bounds.minY)
                        }
                    }
                }

                if minX != .infinity && minY != .infinity {
                }

                for unifiedObj in self.document.snapshot.objects.values {
                    if case .text(let shape) = unifiedObj.objectType {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                }

            } catch {
                Log.error("❌ Failed to load SVG document: \(error)", category: .error)
                throw error
            }
        } else if isFreehand {
            do {
                let parsed = try FreeHandDirectImporter.parseToShapes(data: data)
                Log.info("📂 FH parsed: \(parsed.shapes.count) shapes, \(parsed.layers.count) layers, \(parsed.groupShapeIDs.count) groups, page \(Int(parsed.pageSize.width))×\(Int(parsed.pageSize.height))", category: .general)
                let newDoc = VectorDocument()
                if parsed.pageSize.width > 0 && parsed.pageSize.height > 0 {
                    newDoc.settings.setSizeInPoints(parsed.pageSize)
                    newDoc.onSettingsChanged()
                }

                // Map parsed-layer index → target layer index in the new doc. The doc's
                // default user layer ("Layer 1") is reused for the first parsed layer;
                // additional parsed layers are appended as new native Layers.
                let defaultLayerIndex = newDoc.snapshot.layers.firstIndex(where: { $0.name == "Layer 1" })
                    ?? newDoc.selectedLayerIndex
                    ?? (newDoc.snapshot.layers.count - 1)

                var parsedToDocLayer: [Int: Int] = [:]
                if parsed.layers.isEmpty {
                    parsedToDocLayer[0] = defaultLayerIndex
                } else {
                    for (idx, parsedLayer) in parsed.layers.enumerated() {
                        if idx == 0 {
                            newDoc.snapshot.layers[defaultLayerIndex].name = parsedLayer.name
                            parsedToDocLayer[idx] = defaultLayerIndex
                        } else {
                            newDoc.snapshot.layers.append(parsedLayer)
                            parsedToDocLayer[idx] = newDoc.snapshot.layers.count - 1
                        }
                    }
                }

                // For each parsed shape, find which parsed layer owns it (via objectIDs)
                // and route to the corresponding doc layer. Shapes not owned by any
                // parsed layer fall back to the first-parsed (or default) layer.
                let fallbackLayer = parsedToDocLayer[0] ?? defaultLayerIndex
                var shapeIDToParsedLayer: [UUID: Int] = [:]
                for (idx, parsedLayer) in parsed.layers.enumerated() {
                    for id in parsedLayer.objectIDs { shapeIDToParsedLayer[id] = idx }
                }

                for shape in parsed.shapes {
                    let target = shapeIDToParsedLayer[shape.id].flatMap { parsedToDocLayer[$0] } ?? fallbackLayer
                    newDoc.addImportedShape(shape, to: target)
                }

                let allLayerIndices = Set(0..<newDoc.snapshot.layers.count)
                newDoc.triggerLayerUpdates(for: allLayerIndices)
                self.document = newDoc
            } catch {
                Log.error("❌ Failed to load FreeHand document: \(error) filename=\(configuration.file.preferredFilename ?? "?") ext=\(fileExtension ?? "nil") bytes=\(data.count)", category: .error)
                throw error
            }
        } else if fileExtension == "pdf" {
            do {
                self.document = try FileOperations.importFromPDFData(data)

                for unifiedObj in self.document.snapshot.objects.values {
                    if case .text(let shape) = unifiedObj.objectType {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                }
            } catch {
                Log.error("❌ Failed to load PDF document: \(error)", category: .error)
                throw error
            }
        } else {
            do {
                self.document = try FileOperations.importFromJSONData(data)

                for unifiedObj in self.document.snapshot.objects.values {
                    if case .text(let shape) = unifiedObj.objectType {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                }

            } catch {
                Log.error("❌ Failed to load JSON document: \(error)", category: .error)
                throw error
            }
        }

        // Clean up any orphaned objects left by buggy operations
        self.document.cleanupOrphanedObjects()
        MemoryDiag.checkpoint("InkpenDocument.init DONE (\(configuration.file.preferredFilename ?? "?"))")
        MemoryDiag.dumpObjects(self.document)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        if configuration.contentType == .svg ||
            configuration.contentType.conforms(to: .svg) ||
           configuration.contentType.identifier.contains("svg") {
            do {
                let svgContent = try SVGExporter.shared.exportToSVG(document, includeBackground: false, textRenderingMode: .lines, includeInkpenData: true)
                let data = svgContent.data(using: .utf8) ?? Data()
                return FileWrapper(regularFileWithContents: data)
            } catch {
                Log.error("❌ Failed to save SVG document: \(error)", category: .error)
                throw error
            }
        } else if configuration.contentType == .pdf ||
                  configuration.contentType.conforms(to: .pdf) ||
                  configuration.contentType.identifier.contains("pdf") {
            do {
                let pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: false, textRenderingMode: .lines, includeInkpenData: true, includeBackground: false)
                return FileWrapper(regularFileWithContents: pdfData)
            } catch {
                Log.error("❌ Failed to save PDF document: \(error)", category: .error)
                throw error
            }
        } else {
            do {
                let data = try FileOperations.exportToJSONData(document)
                return FileWrapper(regularFileWithContents: data)
            } catch {
                Log.error("❌ Failed to save JSON document: \(error)", category: .error)
                throw error
            }
        }
    }
}
