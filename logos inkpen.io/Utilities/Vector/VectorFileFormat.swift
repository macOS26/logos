//
//  VectorFileFormat.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics
import UniformTypeIdentifiers
import PDFKit
import AppKit

// MARK: - PROFESSIONAL VECTOR GRAPHICS IMPORT SYSTEM
// Supports: SVG, PDF, and prepares for DWG/DXF

/// Professional file format support matching industry standards
enum VectorFileFormat: String, CaseIterable {
    case svg = "svg"
    case pdf = "pdf"
    case adobeIllustrator = "ai"  // Kept for error handling but not supported
    case dxf = "dxf"          // AutoCAD exchange format (preparation for DWG)a
    case dwf = "dwf"          // Design Web Format (Autodesk published format)
    case dwg = "dwg"          // AutoCAD drawing (future commercial support)
    
    var displayName: String {
        switch self {
        case .svg: return "SVG (Scalable Vector Graphics)"
        case .pdf: return "PDF (Portable Document Format)"
        case .adobeIllustrator: return "AI File (Not Supported)"
        case .dxf: return "AutoCAD Drawing Exchange"
        case .dwf: return "Design Web Format"
        case .dwg: return "AutoCAD Drawing"
        }
    }
    
    var uniformTypeIdentifier: String {
        switch self {
        case .svg: return "public.svg-image"
        case .pdf: return "com.adobe.pdf"
        case .adobeIllustrator: return "com.adobe.illustrator.ai-image"
        case .dxf: return "com.autodesk.dwg"
        case .dwf: return "com.autodesk.dwf"
        case .dwg: return "com.autodesk.dwg"
        }
    }
    
    var isCurrentlySupported: Bool {
        switch self {
        case .svg, .pdf, .dwf: return true
        case .adobeIllustrator, .dxf, .dwg: return false // AI no longer supported
        }
    }
}
