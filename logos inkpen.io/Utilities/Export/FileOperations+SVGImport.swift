//
//  FileOperations+SVGImport.swift
//  logos inkpen.io
//
//  SVG import functionality extracted from FileOperations.swift
//

import Foundation
import AppKit

extension FileOperations {
    
    // MARK: - SVG Import
    
    static func importFromSVG(url: URL) async throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from SVG: \(url.path)", level: .info)
        
        let result = await VectorImportManager.shared.importVectorFile(from: url)
        
        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown SVG import error"
            throw VectorImportError.parsingError("Failed to import SVG: \(errorMessage)", line: nil)
        }
        
        // Create a new VectorDocument from the imported shapes
        let document = VectorDocument()
        
        // FIXED: Use viewBox/document dimensions from SVG file, not calculated bounds
        // This ensures objects stay within their intended viewBox bounds
        let svgDocumentSize = result.metadata.documentSize
        let canvasWidth = max(svgDocumentSize.width, 100) // Minimum 100pt
        let canvasHeight = max(svgDocumentSize.height, 100) // Minimum 100pt
        
        // Set document size based on SVG viewBox/dimensions
        document.settings.width = canvasWidth / 72.0 // Convert to inches
        document.settings.height = canvasHeight / 72.0
        document.settings.unit = .inches
        
        Log.fileOperation("🎯 SVG IMPORT USING VIEWBOX DIMENSIONS:", level: .info)
        Log.info("   SVG document size: \(svgDocumentSize)", category: .general)
        Log.info("   Canvas size: \(canvasWidth) × \(canvasHeight) pts", category: .general)
        print("   Document size: \(String(format: "%.2f", canvasWidth/72.0)) × \(String(format: "%.2f", canvasHeight/72.0)) inches")
        
        // Calculate actual artwork bounds for positioning
        var artworkBounds = CGRect.null
        for shape in result.shapes {
            // CRITICAL FIX: Use transformed bounds to get actual positioned bounds
            let shapeBounds = shape.bounds.applying(shape.transform)
            if artworkBounds.isNull {
                artworkBounds = shapeBounds
            } else {
                artworkBounds = artworkBounds.union(shapeBounds)
            }
        }
        
        if !artworkBounds.isNull {
            Log.info("   Actual artwork bounds: \(artworkBounds)", category: .general)
        }
        
        // VectorDocument init already created Pasteboard, Canvas and Working layers with backgrounds
        // Canvas size already set above in inches - don't override with raw pixel values
        
        // FIXED: Position objects at viewBox origin (0,0), not artwork bounds origin
        // This preserves the intended positioning from the SVG file
        let translateX: CGFloat = 0  // Keep at viewBox origin
        let translateY: CGFloat = 0  // Keep at viewBox origin
        
        Log.fileOperation("🎯 POSITIONING CALCULATION:", level: .info)
        Log.info("   Using viewBox origin (0,0) - preserving SVG positioning", category: .general)
        if !artworkBounds.isNull {
            Log.info("   Artwork bounds: \(artworkBounds)", category: .general)
            if artworkBounds.minX < 0 || artworkBounds.minY < 0 || 
               artworkBounds.maxX > canvasWidth || artworkBounds.maxY > canvasHeight {
                Log.info("   ⚠️ WARNING: Some objects are positioned outside the viewBox bounds!", category: .general)
            }
        }
        
        // Add all imported shapes to the layer with translation applied to coordinates (not transforms)
        for shape in result.shapes {
            var centeredShape = shape
            
            // CRITICAL FIX: Apply centering to actual coordinates, not transforms
            // This prevents coordinate drift during zoom operations
            let centeringTransform = CGAffineTransform(translationX: translateX, y: translateY)
            let finalTransform = shape.transform.concatenating(centeringTransform)
            
            // CRITICAL FIX: Only apply transform if it's not identity
            // This preserves the original shape's properties and bounds
            if !finalTransform.isIdentity {
                centeredShape = applyTransformToShapeCoordinates(shape: centeredShape, transform: finalTransform)
                centeredShape.transform = .identity
            }
            
            // Ensure the shape is editable
            centeredShape.isLocked = false
            centeredShape.isVisible = true
            
            // Debug: Log shape being added with bounds
            Log.fileOperation("✅ Adding SVG shape '\(centeredShape.name)' to unified system at layer 2", level: .debug)
            Log.fileOperation("   📐 Shape bounds: \(centeredShape.bounds)", level: .debug)
            Log.fileOperation("   👁️ Shape visible: \(centeredShape.isVisible)", level: .debug)
            Log.fileOperation("   🎨 Fill: \(centeredShape.fillStyle != nil ? String(describing: centeredShape.fillStyle!.color) : "none")", level: .debug)
            Log.fileOperation("   🖌️ Stroke: \(centeredShape.strokeStyle != nil ? String(describing: centeredShape.strokeStyle!.color) : "none")", level: .debug)
            
            // Add shape to unified system (layer index 2 for imported layer)
            document.addShapeToUnifiedSystem(centeredShape, layerIndex: 2)
        }

        // Text objects are now imported as shapes with isTextObject=true
        
        // Select the working layer which contains imported shapes
        document.selectedLayerIndex = 2 // Working layer is at index 2
        
        // Log warnings if any
        for warning in result.warnings {
            Log.fileOperation("⚠️ SVG Import Warning: \(warning)", level: .info)
        }
        
        Log.info("✅ Successfully imported SVG document with \(result.shapes.count) shapes", category: .fileOperations)
        Log.fileOperation("📐 Canvas sized to exact artwork dimensions: \(canvasWidth) × \(canvasHeight) pts", level: .info)
        return document
    }
    
    /// Import SVG with extreme value handling for radial gradients that cannot be reproduced
    /// Use this for SVGs with extreme coordinate values that cause rendering issues
    static func importFromSVGWithExtremeValueHandling(url: URL) async throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from SVG with extreme value handling: \(url.path)", level: .info)
        
        let result = await VectorImportManager.shared.importSVGWithExtremeValueHandling(from: url)
        
        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown SVG import error"
            throw VectorImportError.parsingError("Failed to import SVG: \(errorMessage)", line: nil)
        }
        
        // Create a new VectorDocument from the imported shapes
        let document = VectorDocument()
        
        // FIXED: Use viewBox/document dimensions from SVG file, not calculated bounds
        // This ensures objects stay within their intended viewBox bounds
        let svgDocumentSize = result.metadata.documentSize
        let canvasWidth = max(svgDocumentSize.width, 100) // Minimum 100pt
        let canvasHeight = max(svgDocumentSize.height, 100) // Minimum 100pt
        
        // Set document size based on SVG viewBox/dimensions
        document.settings.width = canvasWidth / 72.0 // Convert to inches
        document.settings.height = canvasHeight / 72.0
        document.settings.unit = .inches
        
        Log.fileOperation("🎯 SVG IMPORT WITH EXTREME VALUE HANDLING:", level: .info)
        Log.info("   SVG document size: \(svgDocumentSize)", category: .general)
        Log.info("   Canvas size: \(canvasWidth) × \(canvasHeight) pts", category: .general)
        print("   Document size: \(String(format: "%.2f", canvasWidth/72.0)) × \(String(format: "%.2f", canvasHeight/72.0)) inches")
        
        // Calculate actual artwork bounds for positioning
        var artworkBounds = CGRect.null
        for shape in result.shapes {
            // CRITICAL FIX: Use transformed bounds to get actual positioned bounds
            let shapeBounds = shape.bounds.applying(shape.transform)
            if artworkBounds.isNull {
                artworkBounds = shapeBounds
            } else {
                artworkBounds = artworkBounds.union(shapeBounds)
            }
        }
        
        if !artworkBounds.isNull {
            Log.info("   Actual artwork bounds: \(artworkBounds)", category: .general)
        }
        
        // VectorDocument init already created Pasteboard, Canvas and Working layers with backgrounds
        // Canvas size already set above in inches - don't override with raw pixel values
        
        // FIXED: Position objects at viewBox origin (0,0), not artwork bounds origin
        // This preserves the intended positioning from the SVG file
        let translateX: CGFloat = 0  // Keep at viewBox origin
        let translateY: CGFloat = 0  // Keep at viewBox origin
        
        Log.fileOperation("🎯 POSITIONING CALCULATION:", level: .info)
        Log.info("   Using viewBox origin (0,0) - preserving SVG positioning", category: .general)
        if !artworkBounds.isNull {
            Log.info("   Artwork bounds: \(artworkBounds)", category: .general)
            if artworkBounds.minX < 0 || artworkBounds.minY < 0 || 
               artworkBounds.maxX > canvasWidth || artworkBounds.maxY > canvasHeight {
                Log.info("   ⚠️ WARNING: Some objects are positioned outside the viewBox bounds!", category: .general)
            }
        }
        
        // Add all imported shapes to the layer with translation applied to coordinates (not transforms)
        for shape in result.shapes {
            var centeredShape = shape
            
            // CRITICAL FIX: Apply centering to actual coordinates, not transforms
            // This prevents coordinate drift during zoom operations
            let centeringTransform = CGAffineTransform(translationX: translateX, y: translateY)
            let finalTransform = shape.transform.concatenating(centeringTransform)
            
            // CRITICAL FIX: Only apply transform if it's not identity
            // This preserves the original shape's properties and bounds
            if !finalTransform.isIdentity {
                centeredShape = applyTransformToShapeCoordinates(shape: centeredShape, transform: finalTransform)
                centeredShape.transform = .identity
            }
            
            // Ensure the shape is editable
            centeredShape.isLocked = false
            centeredShape.isVisible = true
            
            // Debug: Log shape being added with bounds
            Log.fileOperation("✅ Adding SVG shape '\(centeredShape.name)' to unified system at layer 2", level: .debug)
            Log.fileOperation("   📐 Shape bounds: \(centeredShape.bounds)", level: .debug)
            Log.fileOperation("   👁️ Shape visible: \(centeredShape.isVisible)", level: .debug)
            Log.fileOperation("   🎨 Fill: \(centeredShape.fillStyle != nil ? String(describing: centeredShape.fillStyle!.color) : "none")", level: .debug)
            Log.fileOperation("   🖌️ Stroke: \(centeredShape.strokeStyle != nil ? String(describing: centeredShape.strokeStyle!.color) : "none")", level: .debug)
            
            // Add shape to unified system (layer index 2 for imported layer)
            document.addShapeToUnifiedSystem(centeredShape, layerIndex: 2)
        }

        // Text objects are now imported as shapes with isTextObject=true
        
        // Select the working layer which contains imported shapes
        document.selectedLayerIndex = 2 // Working layer is at index 2
        
        // Log warnings if any
        for warning in result.warnings {
            Log.fileOperation("⚠️ SVG Import Warning: \(warning)", level: .info)
        }
        
        // CRITICAL: Log the unified objects count to verify they were added
        Log.info("🔧 UNIFIED OBJECTS after SVG import: \(document.unifiedObjects.count) objects", category: .fileOperations)
        Log.info("✅ Successfully imported SVG document with extreme value handling: \(result.shapes.count) shapes", category: .fileOperations)
        Log.fileOperation("📐 Canvas sized to exact artwork dimensions: \(canvasWidth) × \(canvasHeight) pts", level: .info)
        return document
    }
    
    /// Synchronous version of SVG import for FileDocument protocol
    static func importFromSVGSync(url: URL) throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from SVG (sync): \(url.path)", level: .info)
        
        // Use a semaphore to make the async call synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var resultDocument: VectorDocument?
        var resultError: Error?
        
        Task {
            do {
                resultDocument = try await importFromSVG(url: url)
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
            throw VectorImportError.parsingError("Failed to import SVG: Unknown error", line: nil)
        }
        
        return document
    }
    
    /// Import SVG from data for FileDocument protocol
    static func importFromSVGData(_ data: Data) throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from SVG data", level: .info)
        
        // Create a temporary file to use with the existing SVG import infrastructure
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("svg")
        
        do {
            try data.write(to: tempURL)
            let document = try importFromSVGSync(url: tempURL)
            
            // CRITICAL FIX: Hydrate images after SVG import so embedded images are loaded
            // This ensures SVG images are properly imported when opening through File > Open
            ImageContentRegistry.setBaseDirectoryURL(tempURL.deletingLastPathComponent())
            // Use unified objects to hydrate all shapes
            for unifiedObject in document.unifiedObjects {
                if case .shape(let shape) = unifiedObject.objectType {
                    _ = ImageContentRegistry.hydrateImageIfAvailable(for: shape)
                }
            }
            
            // Trigger UI refresh after hydration
            DispatchQueue.main.async {
                document.objectWillChange.send()
            }
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempURL)
            
            Log.fileOperation("✅ SVG data import completed with image hydration", level: .info)
            
            return document
        } catch {
            // Clean up temporary file on error
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }
    
    // MARK: - Helper Functions
    
    /// Apply transform to shape coordinates and return new shape with identity transform
    /// This prevents coordinate drift during zoom operations
    static func applyTransformToShapeCoordinates(shape: VectorShape, transform: CGAffineTransform) -> VectorShape {
        // Don't apply identity transforms
        if transform.isIdentity {
            return shape
        }
        
        Log.fileOperation("🔄 Applying transform to SVG shape: \(shape.name)", level: .debug)
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(transform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(transform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new shape with transformed path and identity transform
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        var newShape = shape
        newShape.path = transformedPath
        newShape.transform = .identity
        newShape.updateBounds()
        
        return newShape
    }
}