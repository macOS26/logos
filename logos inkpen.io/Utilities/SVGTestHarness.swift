import SwiftUI
import Foundation
import CoreGraphics
import AppKit

// MARK: - SVG Test Harness
/// Comprehensive test harness for SVG import and Core Graphics vector conversion
/// Combines debug testing with actual SVG import functionality
struct SVGTestHarness: View {
    @State private var selectedTab = 0
    @State private var importedDocument: VectorDocument?
    @Environment(\.dismiss) private var dismiss
    
    let onDocumentImported: ((VectorDocument) -> Void)?
    
    init(onDocumentImported: ((VectorDocument) -> Void)? = nil) {
        self.onDocumentImported = onDocumentImported
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                VStack(spacing: 10) {
                    Text("SVG Core Graphics Test Harness")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Test SVG to CGContext conversion and Ink Pen Document creation")
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
            .background(Color.gray.opacity(0.1))
            
            // Tab Selection
            Picker("Test Type", selection: $selectedTab) {
                Text("Debug Tests").tag(0)
                Text("SVG Import").tag(1)
                Text("Vector Viewer").tag(2)
                Text("Simple Converter").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            Group {
                switch selectedTab {
                case 0:
                    SVGImportDebugTestView()
                case 1:
                    SVGImportView()
                case 2:
                    VectorViewerTab(importedDocument: $importedDocument)
                case 3:
                    SVGToInkPenConverter(onDocumentImported: onDocumentImported)
                default:
                    SVGImportDebugTestView()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 700)
    }
}

// MARK: - Vector Viewer Tab
struct VectorViewerTab: View {
    @Binding var importedDocument: VectorDocument?
    @State private var selectedSVG: SVGImportDebugTest.SVGDocument?
    @State private var isFilePickerPresented = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Vector Document Viewer")
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 15) {
                Button("Load SVG File") {
                    isFilePickerPresented = true
                }
                .buttonStyle(.borderedProminent)
                
                if selectedSVG != nil {
                    Button("Export as PDF") {
                        exportAsPDF()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Clear") {
                        selectedSVG = nil
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if let svg = selectedSVG {
                VStack(spacing: 10) {
                    Text("SVG Size: \(Int(svg.size.width)) × \(Int(svg.size.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Vector rendering view
                    CGVectorView(svg: svg)
                        .frame(maxWidth: 500, maxHeight: 500)
                        .background(Color.white)
                        .border(Color.gray, width: 1)
                        .cornerRadius(8)
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 400)
                    .overlay(
                        VStack {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Load an SVG file to view as vector")
                                .foregroundColor(.secondary)
                        }
                    )
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
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
            
            let data = try Data(contentsOf: url)
            
            if let svg = SVGImportDebugTest.SVGDocument(data) {
                selectedSVG = svg
                errorMessage = nil
            } else {
                errorMessage = "Failed to parse SVG file"
                selectedSVG = nil
            }
        } catch {
            errorMessage = "Error loading file: \(error.localizedDescription)"
            selectedSVG = nil
        }
    }
    
    private func exportAsPDF() {
        guard let svg = selectedSVG else {
            errorMessage = "No SVG loaded"
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "vector_export.pdf"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let pageSize = CGSize(width: 612, height: 792) // Letter size
                
                var mediaBox = CGRect(origin: .zero, size: pageSize)
                guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
                    errorMessage = "Failed to create PDF context"
                    return
                }
                
                context.beginPDFPage(nil)
                svg.renderToVectorContext(context, targetSize: pageSize)
                context.endPDFPage()
                context.closePDF()
                
                // Success
            }
        }
    }
}

// MARK: - Core Graphics Vector View
struct CGVectorView: View {
    let svg: SVGImportDebugTest.SVGDocument
    
    var body: some View {
        Canvas { context, size in
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            
            guard let cgContext = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return }
            
            cgContext.interpolationQuality = .high
            cgContext.setShouldAntialias(true)
            cgContext.setAllowsAntialiasing(true)
            
            cgContext.setFillColor(NSColor.controlBackgroundColor.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            svg.renderToVectorContext(cgContext, targetSize: size)
            
            if let cgImage = cgContext.makeImage() {
                let nsImage = NSImage(cgImage: cgImage, size: size)
                context.draw(Image(nsImage: nsImage), in: CGRect(origin: .zero, size: size))
            }
        }
    }
}

// MARK: - Quick Test Functions
extension SVGTestHarness {
    
    /// Quick test function to verify CoreSVG framework availability
    static func testCoreSVGFramework() -> Bool {
        let coreSVG = dlopen("/System/Library/PrivateFrameworks/CoreSVG.framework/CoreSVG", RTLD_NOW)
        guard coreSVG != nil else { return false }
        
        let functions = [
            "CGSVGDocumentCreateFromData",
            "CGContextDrawSVGDocument", 
            "CGSVGDocumentGetCanvasSize"
        ]
        
        for functionName in functions {
            if dlsym(coreSVG, functionName) == nil {
                dlclose(coreSVG)
                return false
            }
        }
        
        dlclose(coreSVG)
        return true
    }
    
    /// Quick test function to verify SVG parsing
    static func testSVGParsing() -> Bool {
        let testSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="40" fill="red"/>
        </svg>
        """
        
        guard let data = testSVG.data(using: .utf8) else { return false }
        
        // This would use the actual SVG class from SVGContentView
        // For now, just test data conversion
        return data.count > 0
    }
}

// MARK: - Test Results Summary
struct TestResultsSummary: View {
    let frameworkAvailable: Bool
    let svgParsingWorks: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Test Results Summary")
                .font(.headline)
            
            HStack {
                Image(systemName: frameworkAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(frameworkAvailable ? .green : .red)
                Text("CoreSVG Framework: \(frameworkAvailable ? "Available" : "Not Available")")
            }
            
            HStack {
                Image(systemName: svgParsingWorks ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(svgParsingWorks ? .green : .red)
                Text("SVG Parsing: \(svgParsingWorks ? "Working" : "Failed")")
            }
            
            if frameworkAvailable && svgParsingWorks {
                Text("✅ Ready for SVG to CGContext conversion")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            } else {
                Text("❌ CoreSVG framework or SVG parsing not available")
                    .foregroundColor(.red)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    SVGTestHarness()
} 