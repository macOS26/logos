import SwiftUI
import UniformTypeIdentifiers
import Combine

struct InkpenDocument: FileDocument {
    var document: VectorDocument

    static var readableContentTypes: [UTType] { [.inkpen, .svg, .pdf] }
    static var writableContentTypes: [UTType] { [.inkpen, .svg, .pdf] }

    init() {
        self.document = VectorDocument()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let fileExtension = configuration.file.preferredFilename?.components(separatedBy: ".").last?.lowercased()

        if fileExtension == "svg" {
            do {
                self.document = try FileOperations.importFromSVGData(data)

                self.document.populateUnifiedObjectsFromLayersPreservingOrder()

                var minX: CGFloat = .infinity
                var minY: CGFloat = .infinity

                for unifiedObj in self.document.unifiedObjects {
                    if case .shape(let shape) = unifiedObj.objectType {
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
                    self.document.canvasOffset = CGPoint(x: -minX, y: -minY)
                }

                for unifiedObj in self.document.unifiedObjects {
                    if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                }

            } catch {
                Log.error("❌ Failed to load SVG document: \(error)", category: .error)
                throw error
            }
        } else if fileExtension == "pdf" {
            do {
                self.document = try FileOperations.importFromPDFData(data)
                self.document.populateUnifiedObjectsFromLayersPreservingOrder()

                for unifiedObj in self.document.unifiedObjects {
                    if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
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

                for unifiedObj in self.document.unifiedObjects {
                    if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                }

                if self.document.unifiedObjects.isEmpty {
                    self.document.populateUnifiedObjectsFromLayersPreservingOrder()
                }
            } catch {
                Log.error("❌ Failed to load JSON document: \(error)", category: .error)
                throw error
            }
        }
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
