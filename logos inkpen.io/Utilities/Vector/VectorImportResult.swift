//
//  VectorImportResult.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

/// Professional import result with comprehensive metadata
struct VectorImportResult: Identifiable {
    let id = UUID()
    let success: Bool
    let shapes: [VectorShape]
    let metadata: VectorImportMetadata
    let errors: [VectorImportError]
    let warnings: [String]
}

/// Complete metadata for imported vector graphics
struct VectorImportMetadata {
    let originalFormat: VectorFileFormat
    let documentSize: CGSize
    let viewBoxSize: CGSize?  // Added to detect 96 DPI SVGs
    let colorSpace: String
    let units: VectorUnit
    let dpi: Double
    let layerCount: Int
    let shapeCount: Int
    let textObjectCount: Int
    let importDate: Date
    let sourceApplication: String?
    let documentVersion: String?
}

/// Professional vector graphics units
enum VectorUnit: String, CaseIterable {
    case points = "pt"        // 1/72 inch (standard)
    case inches = "in"        // Imperial
    case millimeters = "mm"   // Metric
    case pixels = "px"        // Screen
    case picas = "pc"         // Typography
    
    var pointsPerUnit: Double {
        switch self {
        case .points: return 1.0
        case .inches: return 72.0
        case .millimeters: return 72.0 / 25.4
        case .pixels: return 1.0  // Depends on DPI
        case .picas: return 12.0
        }
    }
}

/// Comprehensive import error types
enum VectorImportError: Error, LocalizedError {
    case fileNotFound
    case unsupportedFormat(VectorFileFormat)
    case corruptedFile
    case invalidStructure(String)
    case missingFonts([String])
    case colorSpaceNotSupported(String)
    case scalingError(String)
    case parsingError(String, line: Int?)
    case commercialLicenseRequired(VectorFileFormat)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found or inaccessible"
        case .unsupportedFormat(let format):
            return "Unsupported file format: \(format.displayName)"
        case .corruptedFile:
            return "File appears to be corrupted or incomplete"
        case .invalidStructure(let detail):
            return "Invalid file structure: \(detail)"
        case .missingFonts(let fonts):
            return "Missing fonts: \(fonts.joined(separator: ", "))"
        case .colorSpaceNotSupported(let colorSpace):
            return "Color space not supported: \(colorSpace)"
        case .scalingError(let detail):
            return "Scaling conversion error: \(detail)"
        case .parsingError(let detail, let line):
            if let line = line {
                return "Parsing error at line \(line): \(detail)"
            } else {
                return "Parsing error: \(detail)"
            }
        case .commercialLicenseRequired(let format):
            return "\(format.displayName) requires commercial license (Open Design Alliance)"
        }
    }
}
