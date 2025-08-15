import SwiftUI
import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

// MARK: - Simple SVG to Ink Pen Converter
/// User-friendly interface for converting SVG files to Ink Pen documents
struct SVGToInkPenConverter: View {
    @StateObject private var importer = SVGToInkPenImporter()
    @State private var isFilePickerPresented = false
    @State private var importedDocument: VectorDocument?
    @State private var currentStep = 1
    @State private var showingInstructions = true
    @Environment(\.dismiss) private var dismiss
    
    let onDocumentImported: ((VectorDocument) -> Void)?
    
    init(onDocumentImported: ((VectorDocument) -> Void)? = nil) {
        self.onDocumentImported = onDocumentImported
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with close button
            HStack {
                VStack(spacing: 10) {
                    Text("SVG to Ink Pen Converter")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Convert SVG files to editable vector documents")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            if showingInstructions {
                // Step-by-step instructions
                VStack(alignment: .leading, spacing: 15) {
                    Text("How to Convert SVG to Ink Pen Document:")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        StepView(number: 1, title: "Select SVG File", description: "Choose an SVG file from your computer")
                        StepView(number: 2, title: "Import & Convert", description: "The SVG will be parsed and converted to vector shapes")
                        StepView(number: 3, title: "Review Results", description: "Check the imported document and its layers")
                        StepView(number: 4, title: "Use in Ink Pen", description: "The document is ready for editing in your vector app")
                    }
                    
                    Button("Start Conversion") {
                        showingInstructions = false
                        isFilePickerPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 10)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 2)
            } else {
                // Conversion interface
                VStack(spacing: 20) {
                    // File selection
                    VStack(spacing: 10) {
                        Text("Step 1: Select SVG File")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Button("Choose SVG File") {
                            isFilePickerPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(importer.isImporting)
                    }
                    
                    // Progress indicator
                    if importer.isImporting {
                        VStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(importer.currentOperation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Results
                    if let document = importedDocument {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("✅ Conversion Complete!")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Document Size: \(String(format: "%.1f", document.settings.width)) × \(String(format: "%.1f", document.settings.height)) \(document.settings.unit.rawValue)")
                                Text("Layers: \(document.layers.count)")
                                Text("Total Shapes: \(document.layers.reduce(0) { $0 + $1.shapes.count })")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Text("Your SVG has been successfully converted to an Ink Pen document with vector shapes that can be edited, scaled, and exported.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Action buttons for the imported document
                            HStack(spacing: 10) {
                                Button("Open in Ink Pen") {
                                    onDocumentImported?(document)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Save Document") {
                                    saveDocument(document)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.top, 10)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // Action buttons
                    HStack(spacing: 15) {
                        Button("Convert Another SVG") {
                            importedDocument = nil
                            importer.importResults.removeAll()
                            isFilePickerPresented = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(importedDocument == nil)
                        
                        Button("Show Instructions") {
                            showingInstructions = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [.svg, .xml],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            
            importedDocument = importer.importSVGFile(from: url)
            
        } catch {
            Log.info("Error selecting file: \(error.localizedDescription)", category: .general)
        }
    }
    
    private func saveDocument(_ document: VectorDocument) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "imported_svg_document.json"
        savePanel.title = "Save Ink Pen Document"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(document)
                    try data.write(to: url)
                } catch {
                    Log.info("Error saving document: \(error.localizedDescription)", category: .general)
                }
            }
        }
    }
}

// MARK: - Step View
struct StepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 30, height: 30)
                
                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Step content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    SVGToInkPenConverter()
} 