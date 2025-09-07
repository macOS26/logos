//
//  VectorDocument+DocumentProperties.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

// MARK: - Document Properties
extension VectorDocument {
    /// Professional document unit system
    var documentUnits: VectorUnit {
        get {
            switch settings.unit {
            case .inches: return .inches
            case .centimeters: return .millimeters // Map centimeters to millimeters for export
            case .millimeters: return .millimeters
            case .points: return .points
            case .pixels: return .points // Treat pixels as points for compatibility
            case .picas: return .points // Convert picas to points for compatibility
            }
        }
    }
    
    /// Calculate document bounds encompassing all content
    func getDocumentBounds() -> CGRect {
        var documentBounds = CGRect.zero
        var hasContent = false
        
        // Include all visible shapes from all layers
        for layer in layers {
            guard layer.isVisible else { continue }
            
            let layerIndex = layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = getShapesForLayer(layerIndex)
            for shape in shapesInLayer {
                guard shape.isVisible else { continue }
                
                let shapeBounds = shape.bounds
                if !hasContent {
                    documentBounds = shapeBounds
                    hasContent = true
                } else {
                    documentBounds = documentBounds.union(shapeBounds)
                }
            }
        }
        
        // Include all visible text objects
        for textObj in allTextObjects {
            guard textObj.isVisible else { continue }
            
            let textBounds = textObj.bounds
            if !hasContent {
                documentBounds = textBounds
                hasContent = true
            } else {
                documentBounds = documentBounds.union(textBounds)
            }
        }
        
        // If no content, use document settings as bounds
        if !hasContent {
            documentBounds = CGRect(origin: .zero, size: settings.sizeInPoints)
        }
        
        return documentBounds
    }

    /// Calculate bounds of user artwork only (excludes Pasteboard and Canvas layers)
    /// Returns nil when no artwork exists on user layers.
    func getArtworkBounds() -> CGRect? {
        var artworkBounds: CGRect = .zero
        var hasContent = false

        // Consider only layers beyond index 1 (skip 0: Pasteboard, 1: Canvas)
        for (layerIndex, layer) in layers.enumerated() where layerIndex >= 2 {
            guard layer.isVisible else { continue }
            let shapesInLayer = getShapesForLayer(layerIndex)
            for shape in shapesInLayer where shape.isVisible {
                let shapeBounds = shape.bounds.applying(shape.transform)
                if !hasContent {
                    artworkBounds = shapeBounds
                    hasContent = true
                } else {
                    artworkBounds = artworkBounds.union(shapeBounds)
                }
            }
        }

        // Include visible text objects that belong to user layers (>= 2)
        for textObj in allTextObjects where textObj.isVisible {
            if let li = textObj.layerIndex, li >= 2 {
                let textBounds = CGRect(
                    x: textObj.position.x + textObj.bounds.minX,
                    y: textObj.position.y + textObj.bounds.minY,
                    width: textObj.bounds.width,
                    height: textObj.bounds.height
                ).applying(textObj.transform)
                if !hasContent {
                    artworkBounds = textBounds
                    hasContent = true
                } else {
                    artworkBounds = artworkBounds.union(textBounds)
                }
            }
        }

        return hasContent ? artworkBounds : nil
    }
}