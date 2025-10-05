//
//  FileOperations+SVGImport.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI

// MARK: - SVG Import Extensions
extension FileOperations {
    // MARK: - Data-based SVG Import (for FileDocument)
    static func importFromSVGData(_ data: Data) throws -> VectorDocument {
        // Create a temporary file to use with the existing import function
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).svg")
        try data.write(to: tempURL)
        
        defer {
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Use async context to call the async import function
        let document = try runBlocking {
            try await openSVGFile(url: tempURL)
        }
        
        return document
    }
    
    // Helper function to run async code in a synchronous context
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
    
    // MARK: - SVG Import with Professional Vector Import Manager
    
    @MainActor
    static func openSVGFile(url: URL) async throws -> VectorDocument {
        Log.fileOperation("🔄 Opening SVG file: \(url.lastPathComponent)", level: .info)
        
        // Create new document with default Canvas and Pasteboard layers
        let document = VectorDocument(settings: DocumentSettings())
        
        // Don't remove the Canvas and Pasteboard layers - they were properly created in init
        // Just clear any unified objects that aren't the canvas/pasteboard backgrounds
        let canvasAndPasteboardObjects = document.unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.name == "Canvas Background" || shape.name == "Pasteboard Background"
            }
            return false
        }
        document.unifiedObjects = canvasAndPasteboardObjects
        
        // Import SVG with extreme value handling for radial gradients that cannot be reproduced
        // Use this for SVGs with extreme coordinate values that cause rendering issues
        let result = await VectorImportManager.shared.importSVGWithExtremeValueHandling(from: url)

        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown SVG import error"
            throw VectorImportError.parsingError("Failed to import SVG: \(errorMessage)", line: nil)
        }

        // Check if SVG contains embedded inkpen metadata
        if let inkpenMetadata = result.metadata.inkpenMetadata {
            Log.info("📦 Found embedded inkpen document in SVG, using native data", category: .fileOperations)

            // Decode base64 and parse as JSON
            guard let inkpenData = Data(base64Encoded: inkpenMetadata) else {
                Log.error("❌ Failed to decode inkpen metadata from base64", category: .error)
                throw VectorImportError.parsingError("Invalid inkpen metadata encoding", line: nil)
            }

            // Parse as inkpen document
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let inkpenDocument = try decoder.decode(VectorDocument.self, from: inkpenData)

            // Return the original inkpen document
            Log.info("✅ Successfully restored inkpen document from SVG metadata", category: .fileOperations)
            return inkpenDocument
        }

        Log.fileOperation("📊 Imported \(result.shapes.count) shapes from SVG", level: .info)
        
        // Update document settings based on imported metadata
        let metadata = result.metadata
        let docSize = metadata.documentSize

        // Detect if this is a 96 DPI SVG (AutoCAD format)
        // Check if documentSize is larger than viewBoxSize by approximately 4/3 (96/72)
        if let viewBoxSize = metadata.viewBoxSize {
            let widthRatio = docSize.width / viewBoxSize.width
            let heightRatio = docSize.height / viewBoxSize.height

            // Check if the ratio is approximately 96/72 (1.333...)
            if abs(widthRatio - (96.0/72.0)) < 0.1 && abs(heightRatio - (96.0/72.0)) < 0.1 {
                // This is likely a 96 DPI SVG (AutoCAD format)
                Log.fileOperation("🔍 Detected 96 DPI SVG (AutoCAD format), using viewBox dimensions", level: .info)

                // Use viewBox size for document dimensions (already in 72 DPI)
                document.settings.width = viewBoxSize.width / 72.0
                document.settings.height = viewBoxSize.height / 72.0
            } else {
                // Standard 72 DPI SVG
                document.settings.width = docSize.width / 72.0
                document.settings.height = docSize.height / 72.0
            }
        } else {
            // No viewBox, use document size as-is
            document.settings.width = docSize.width / 72.0
            document.settings.height = docSize.height / 72.0
        }

        Log.fileOperation("📐 Document size: \(document.settings.width * 72.0) × \(document.settings.height * 72.0) points", level: .info)
        
        // Update Canvas and Pasteboard layers to match new document size
        document.updateCanvasLayer()
        document.updatePasteboardLayer()
        
        // Create the imported content layer (keeping Canvas and Pasteboard layers at indices 0 and 1)
        let importedLayer = VectorLayer(name: "Imported SVG", isVisible: true, isLocked: false, opacity: 1.0, blendMode: .normal)
        
        // Add the imported layer as the third layer (index 2)
        if document.layers.count < 3 {
            document.layers.append(importedLayer)
        } else {
            document.layers[2] = importedLayer
        }
        
        // Group shapes by clipping mask relationships
        var clippingMasks: [UUID: (mask: VectorShape, clippedShapes: [VectorShape])] = [:]
        var standaloneShapes: [VectorShape] = []

        // First pass: identify clipping masks and their relationships
        for shape in result.shapes {
            if shape.isClippingPath {
                // This is a clipping mask
                if clippingMasks[shape.id] == nil {
                    clippingMasks[shape.id] = (mask: shape, clippedShapes: [])
                } else {
                    clippingMasks[shape.id]?.mask = shape
                }
            } else if let clipId = shape.clippedByShapeID {
                // This shape is clipped by another shape
                if clippingMasks[clipId] == nil {
                    // Create placeholder for mask that will be found later
                    clippingMasks[clipId] = (mask: VectorShape(name: "Placeholder", path: VectorPath(elements: [])), clippedShapes: [shape])
                } else {
                    clippingMasks[clipId]?.clippedShapes.append(shape)
                }
            } else {
                // Standalone shape without clipping
                // CRITICAL FIX: Skip invalid shapes
                let shouldSkip: Bool = {
                    // Skip non-text shapes with empty paths (e.g., <path d=""/>)
                    if !shape.isTextObject && shape.path.elements.isEmpty {
                        return true
                    }
                    // Skip text objects with no content or only whitespace
                    if shape.isTextObject {
                        let textContent = shape.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        if textContent.isEmpty {
                            return true
                        }
                    }
                    return false
                }()

                if !shouldSkip {
                    standaloneShapes.append(shape)
                } else {
                    Log.fileOperation("⚠️ Skipping invalid shape: \(shape.name)", level: .debug)
                }
            }
        }
        
        // CRITICAL FIX: Add standalone shapes in reverse order to preserve visual stacking
        // SVG renders first elements at bottom, last elements at top
        // So we reverse the order when adding to unified system
        for shape in standaloneShapes.reversed() {
            // Keep shape at its original position - no centering
            Log.fileOperation("🔷 Adding standalone shape: \(shape.name)", level: .debug)
            Log.fileOperation("   📍 Position: \(shape.bounds.origin)", level: .debug)
            Log.fileOperation("   📏 Size: \(shape.bounds.size)", level: .debug)
            Log.fileOperation("   🎨 Fill: \(shape.fillStyle.map { String(describing: $0.color) } ?? "none")", level: .debug)
            Log.fileOperation("   🖌️ Stroke: \(shape.strokeStyle.map { String(describing: $0.color) } ?? "none")", level: .debug)

            // Add shape to unified system (layer index 2 for imported layer)
            document.addShapeToUnifiedSystem(shape, layerIndex: 2)
        }
        
        // Add clipping mask groups
        // CRITICAL: Must add shapes in the correct order for InkPen's clipping mask system
        for (maskId, maskGroup) in clippingMasks {
            // Skip if we don't have a valid mask (placeholder)
            guard maskGroup.mask.name != "Placeholder" else { continue }

            // IMPORTANT: Add clipped shapes FIRST (they go under the mask in InkPen's system)
            for clippedShape in maskGroup.clippedShapes {
                // Keep shape at its original position - no centering
                Log.fileOperation("🔶 Adding clipped shape: \(clippedShape.name)", level: .debug)
                Log.fileOperation("   🎭 Clipped by: \(maskId.uuidString.prefix(8))", level: .debug)

                // Add shape to unified system
                document.addShapeToUnifiedSystem(clippedShape, layerIndex: 2)
            }

            // Then add the clipping mask LAST (it goes on top in InkPen's system)
            // Keep mask at its original position - no centering
            Log.fileOperation("🎭 Adding clipping mask: \(maskGroup.mask.name)", level: .debug)
            Log.fileOperation("   📍 Position: \(maskGroup.mask.bounds.origin)", level: .debug)
            Log.fileOperation("   📏 Size: \(maskGroup.mask.bounds.size)", level: .debug)

            // Add mask to unified system
            document.addShapeToUnifiedSystem(maskGroup.mask, layerIndex: 2)
        }
        
        // Text objects are now imported as shapes with isTextObject=true
        // They were already processed above as shapes

        // CRITICAL FIX: Align text boxes that are slightly misaligned
        alignTextBoxes(in: document, tolerance: 3.0)

        // Force sync unified objects
        document.forceResyncUnifiedObjects()
        
        // Select the imported layer
        document.selectedLayerIndex = 2
        
        Log.fileOperation("✅ SVG import complete: \(document.unifiedObjects.count) objects in document", level: .info)
        
        return document
    }

    // MARK: - Text Box Alignment Helper

    /// Aligns text box edges (left/right) within tolerance to snap to common alignment
    private static func alignTextBoxes(in document: VectorDocument, tolerance: Double) {
        // Get all text objects
        var textShapes: [(id: UUID, shape: VectorShape, left: Double, right: Double)] = []

        for obj in document.unifiedObjects {
            if case .shape(let shape) = obj.objectType, shape.isTextObject {
                let position = shape.textPosition ?? CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                let width = shape.areaSize?.width ?? shape.bounds.width
                let left = position.x
                let right = position.x + width
                textShapes.append((id: shape.id, shape: shape, left: left, right: right))
            }
        }

        guard textShapes.count > 1 else { return }

        // Find common left edges (multiple text boxes with same left X)
        var leftEdges: [Double: Int] = [:]
        for text in textShapes {
            // Round to find nearby edges
            let roundedLeft = round(text.left)
            leftEdges[roundedLeft, default: 0] += 1
        }

        // Find common right edges
        var rightEdges: [Double: Int] = [:]
        for text in textShapes {
            let roundedRight = round(text.right)
            rightEdges[roundedRight, default: 0] += 1
        }

        // Find the most common right edge (where most text boxes align)
        let mostCommonRight = rightEdges.max(by: { $0.value < $1.value })?.key

        // Snap text boxes to common alignment
        for text in textShapes {
            var needsUpdate = false
            var newWidth = text.shape.areaSize?.width ?? text.shape.bounds.width

            // If this text box's right edge is close to the common right edge, snap it
            if let commonRight = mostCommonRight {
                let rightDiff = abs(text.right - commonRight)
                if rightDiff > 0.5 && rightDiff <= tolerance {
                    // Adjust width to align right edge
                    newWidth = commonRight - text.left
                    needsUpdate = true
                    Log.fileOperation("📐 Aligning text box '\(text.shape.textContent?.prefix(20) ?? "")' right edge: \(text.right) → \(commonRight) (diff: \(rightDiff)pt)", level: .debug)
                }
            }

            // Update the text object's area size
            if needsUpdate, let index = document.unifiedObjects.firstIndex(where: { $0.id == text.id }) {
                if case .shape(var shape) = document.unifiedObjects[index].objectType {
                    shape.areaSize = CGSize(width: newWidth, height: shape.areaSize?.height ?? shape.bounds.height)
                    let obj = document.unifiedObjects[index]
                    document.unifiedObjects[index] = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: obj.orderID)
                }
            }
        }
    }
}