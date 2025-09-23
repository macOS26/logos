//
//  ExportView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    @State private var exportFormat: ExportFormat = .svg
    @State private var exportScale: Double = 1.0  // For PNG scale (1x, 2x, 3x, etc.)
    @State private var exportQuality: Double = 0.9  // For JPEG quality (0.1-1.0)
    @State private var includeBackground: Bool = true  // For SVG/PNG background inclusion
    
    enum ExportFormat: String, CaseIterable {
        case svg = "SVG"
        case pdf = "PDF"
        case png = "PNG"
        
        var fileExtension: String {
            switch self {
            case .svg: return "svg"
            case .pdf: return "pdf"
            case .png: return "png"
            }
        }
        
        var contentType: UTType {
            switch self {
            case .svg: return .svg
            case .pdf: return .pdf
            case .png: return .png
            }
        }
    }
    
    var body: some View {
        NavigationView {
            exportForm
        }
        .navigationTitle("Export Document")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Export") {
                    exportDocument()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private var exportForm: some View {
        Form {
            Section(header: Text("Export Format")) {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if exportFormat == .svg || exportFormat == .png || exportFormat == .pdf {
                    Section(header: Text("Options")) {
                        Toggle("Include Background", isOn: $includeBackground)
                            .help("Include the canvas background layer in the export")
                    }
                }

                if exportFormat == .png {
                    Section(header: Text("Resolution")) {
                        HStack {
                            Text("Scale:")
                            Spacer()
                            Picker("Scale", selection: $exportScale) {
                                Text("1x").tag(1.0)
                                Text("2x").tag(2.0)
                                Text("3x").tag(3.0)
                                Text("4x").tag(4.0)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        let size = document.settings.sizeInPoints
                        Text("Output size: \(Int(size.width * exportScale))×\(Int(size.height * exportScale)) pixels")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                
                Section(header: Text("Export Options")) {
                    Text("Size: \(Int(document.settings.sizeInPoints.width))×\(Int(document.settings.sizeInPoints.height)) points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Layers: \(document.layers.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Objects: \(document.unifiedObjects.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    
    private func exportDocument() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [exportFormat.contentType]
        panel.nameFieldStringValue = "Document.\(exportFormat.fileExtension)"
        panel.title = "Export as \(exportFormat.rawValue)"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            do {
                switch exportFormat {
                case .svg:
                    try FileOperations.exportToSVG(document, url: url, includeBackground: includeBackground)
                case .pdf:
                    try FileOperations.exportToPDF(document, url: url, includeBackground: includeBackground)
                case .png:
                    try FileOperations.exportToPNG(document, url: url, scale: CGFloat(exportScale), includeBackground: includeBackground)
                }
                
                Log.info("✅ Successfully exported document as \(exportFormat.rawValue) to: \(url.path)", category: .fileOperations)
                
            } catch {
                Log.error("❌ Export failed: \(error)", category: .error)
                
                // Show error notification
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = "Error: \(error.localizedDescription)"
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }
}
