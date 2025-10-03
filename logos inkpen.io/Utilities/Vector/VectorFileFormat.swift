//
//  VectorFileFormat.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import AppKit

// MARK: - PROFESSIONAL VECTOR GRAPHICS IMPORT SYSTEM
// Supports: SVG, PDF

/// Professional file format support matching industry standards
enum VectorFileFormat: String, CaseIterable {
    case svg = "svg"
    case pdf = "pdf"
    
    var displayName: String {
        switch self {
        case .svg: return "SVG (Scalable Vector Graphics)"
        case .pdf: return "PDF (Portable Document Format)"
        }
    }
    
    var uniformTypeIdentifier: String {
        switch self {
        case .svg: return "public.svg-image"
        case .pdf: return "com.adobe.pdf"
        }
    }
    
    var isCurrentlySupported: Bool {
        switch self {
        case .svg, .pdf: return true
        }
    }
}
