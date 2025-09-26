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
    @State private var isIconExport: Bool = false  // For PNG icon set export (disabled when sandboxed)

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
                    // Only show icon set export option when not sandboxed
                    if SandboxChecker.isNotSandboxed {
                        Section(header: Text("PNG Export Type")) {
                            Toggle("Export as Icon Set", isOn: $isIconExport)
                                .help("Export multiple icon sizes (16x16 to 1024x1024) without background")
                        }
                    }

                    if !isIconExport {
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
                    } else {
                        Section(header: Text("Icon Sizes")) {
                            Text("Will export: 1024×1024, 512×512, 256×256, 128×128, 64×64, 32×32, 16×16 px")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Background will not be included")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
        // Don't allow icon export when sandboxed
        if exportFormat == .png && isIconExport && SandboxChecker.isNotSandboxed {
            // For icon export, let user choose a folder
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.title = "Choose folder for icon set export"
            panel.prompt = "Export Icons"

            panel.begin { response in
                guard response == .OK, let folderURL = panel.url else { return }

                do {
                    try FileOperations.exportIconSet(document, folderURL: folderURL)
                    Log.info("✅ Successfully exported icon set to: \(folderURL.path)", category: .fileOperations)
                } catch {
                    self.showExportError(error)
                }
            }
        } else {
            // Regular single file export
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
                    self.showExportError(error)
                }
            }
        }
    }

    private func showExportError(_ error: Error) {
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
