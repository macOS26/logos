//
//  AdobeIllustrator.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI
import CoreGraphics

struct AIContent {
    let embeddedPDFURL: URL?
    let layerCount: Int
    let version: String?
}

func parseAdobeIllustratorFile(_ url: URL) throws -> AIContent {
            Log.fileOperation("🔧 Implementing professional AI file parser...", level: .info)
    
    guard let data = try? Data(contentsOf: url) else {
        throw VectorImportError.fileNotFound
    }
    
            // AI files often contain both PostScript and embedded PDF data
    // Look for embedded PDF section
    guard let fileContent = String(data: data, encoding: .utf8) else {
        throw VectorImportError.parsingError("Could not decode AI file as UTF-8", line: nil)
    }
    
    var embeddedPDFURL: URL?
    var layerCount = 1
    var version: String?
    
    // Check if it contains PDF data
    if fileContent.contains("%PDF-") {
        Log.fileOperation("📋 Found embedded PDF data in AI file", level: .info)
        
        // Extract the PDF portion from the AI file
        if let pdfStartRange = fileContent.range(of: "%PDF-") {
            let pdfStart = pdfStartRange.lowerBound
            
            // Find the end of PDF (look for %%EOF or end of file)
            var pdfEndRange: Range<String.Index>?
            if let eofRange = fileContent.range(of: "%%EOF", range: pdfStart..<fileContent.endIndex) {
                pdfEndRange = pdfStart..<fileContent.index(after: eofRange.upperBound)
            } else {
                pdfEndRange = pdfStart..<fileContent.endIndex
            }
            
            if let pdfRange = pdfEndRange {
                let pdfString = String(fileContent[pdfRange])
                let pdfData = pdfString.data(using: .utf8)!
                
                // Create temporary file for the embedded PDF
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("pdf")
                
                try pdfData.write(to: tempURL)
                embeddedPDFURL = tempURL
                
                Log.info("✅ Extracted embedded PDF to temporary file", category: .fileOperations)
            }
        }
    }
    
    // Parse AI version from header
            if let versionRange = fileContent.range(of: "%%Creator: AI File") {
        let versionStart = versionRange.upperBound
        if let versionEnd = fileContent.range(of: "\n", range: versionStart..<fileContent.endIndex) {
            version = String(fileContent[versionStart..<versionEnd.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
    }
    
    // Count layers (look for layer definitions)
    let layerPattern = "%%Layer:"
    layerCount = fileContent.components(separatedBy: layerPattern).count - 1
    if layerCount <= 0 { layerCount = 1 }
    
                Log.info("✅ AI file parsing completed - Found \(layerCount) layers", category: .fileOperations)
    
    return AIContent(
        embeddedPDFURL: embeddedPDFURL,
        layerCount: layerCount,
        version: version
    )
}
