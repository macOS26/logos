//
//  InkpenDocument.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - InkpenDocument for DocumentGroup (ADDITION - not replacement)
struct InkpenDocument: FileDocument {
    var document: VectorDocument
    
    static var readableContentTypes: [UTType] { [.inkpen] }
    
    init() {
        self.document = VectorDocument()
    }
    
    init(document: VectorDocument) {
        self.document = document
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        do {
            self.document = try FileOperations.importFromJSONData(data)
        } catch {
            Log.error("❌ Failed to load document: \(error)", category: .error)
            throw error
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        do {
            let data = try FileOperations.exportToJSONData(document)
            return FileWrapper(regularFileWithContents: data)
        } catch {
            Log.error("❌ Failed to save document: \(error)", category: .error)
            throw error
        }
    }
}
