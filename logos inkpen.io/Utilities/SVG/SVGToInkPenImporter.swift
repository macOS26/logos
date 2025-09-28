import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - SVG to Ink Pen Document Importer
/// Advanced SVG importer that converts SVG files to Ink Pen Document format
/// Uses CoreSVG framework for high-quality vector conversion and parsing
class SVGToInkPenImporter: ObservableObject {
    
    // MARK: - SVG Shape Registry
    /// Global registry to store SVG data for shapes that contain SVG content
    static var svgShapeRegistry: [UUID: (data: Data, document: SVGDocument)] = [:]
    
    // MARK: - Import Results
    @Published var importResults: [ImportResult] = []
    @Published var currentOperation: String = "Ready"
    @Published var isImporting: Bool = false
    
    struct ImportResult: Identifiable {
        let id = UUID()
        let operation: String
        let success: Bool
        let message: String
        let details: String
        let timestamp: Date
    }
    
    // MARK: - CoreSVG Framework Bridge
    @objc class CGSVGDocument: NSObject { }
    
    static let CoreSVG = dlopen("/System/Library/PrivateFrameworks/CoreSVG.framework/CoreSVG", RTLD_NOW)

    static var CGSVGDocumentRelease: (@convention(c) (CGSVGDocument?) -> Void) = load("CGSVGDocumentRelease")
    static var CGSVGDocumentCreateFromData: (@convention(c) (CFData?, CFDictionary?) -> Unmanaged<CGSVGDocument>?) = load("CGSVGDocumentCreateFromData")
    static var CGContextDrawSVGDocument: (@convention(c) (CGContext?, CGSVGDocument?) -> Void) = load("CGContextDrawSVGDocument")
    static var CGSVGDocumentGetCanvasSize: (@convention(c) (CGSVGDocument?) -> CGSize) = load("CGSVGDocumentGetCanvasSize")
    
    static func load<T>(_ name: String) -> T {
        unsafeBitCast(dlsym(CoreSVG, name), to: T.self)
    }
    
    // MARK: - SVG Document Class
    class SVGDocument {
        deinit { SVGToInkPenImporter.CGSVGDocumentRelease(document) }
        
        let document: CGSVGDocument
        
        init?(_ data: Data) {
            guard let document = SVGToInkPenImporter.CGSVGDocumentCreateFromData(data as CFData, nil)?.takeUnretainedValue() else { return nil }
            guard SVGToInkPenImporter.CGSVGDocumentGetCanvasSize(document) != .zero else { return nil }
            self.document = document
        }
        
        var size: CGSize {
            SVGToInkPenImporter.CGSVGDocumentGetCanvasSize(document)
        }
        
        func renderToVectorContext(_ context: CGContext, targetSize: CGSize) {
            let originalSize = self.size
            
            context.saveGState()
            
            let scaleX = targetSize.width / originalSize.width
            let scaleY = targetSize.height / originalSize.height
            let scale = min(scaleX, scaleY)
            
            let scaledWidth = originalSize.width * scale
            let scaledHeight = originalSize.height * scale
            let offsetX = (targetSize.width - scaledWidth) / 2
            let offsetY = (targetSize.height - scaledHeight) / 2
            
            context.translateBy(x: offsetX, y: offsetY + scaledHeight)
            context.scaleBy(x: scale, y: -scale)
            
            SVGToInkPenImporter.CGContextDrawSVGDocument(context, document)
            
            context.restoreGState()
        }
    }
    
    // MARK: - Import Methods
    
    /// Import SVG file and convert to VectorDocument
    func importSVGFile(from url: URL) -> VectorDocument? {
        isImporting = true
        importResults.removeAll()
        
        addResult("Starting SVG Import", success: true, message: "Processing file: \(url.lastPathComponent)")
        
        do {
            let data = try Data(contentsOf: url)
            addResult("File Loaded", success: true, message: "File size: \(data.count) bytes")
            
            guard let svgDoc = SVGDocument(data) else {
                addResult("SVG Parsing Failed", success: false, message: "Could not parse SVG document")
                isImporting = false
                return nil
            }
            
            addResult("SVG Parsed", success: true, message: "Document size: \(Int(svgDoc.size.width)) × \(Int(svgDoc.size.height))")
            
            // Create VectorDocument from SVG with original data
            let document = createVectorDocumentFromSVG(svgDoc, svgData: data)
            
            addResult("Import Complete", success: true, message: "Created document with \(document.layers.count) layers")
            isImporting = false
            
            return document
            
        } catch {
            addResult("File Loading Failed", success: false, message: "Error: \(error.localizedDescription)")
            isImporting = false
            return nil
        }
    }
    
    /// Import SVG string and convert to VectorDocument
    func importSVGString(_ svgString: String, name: String = "Imported SVG") -> VectorDocument? {
        isImporting = true
        importResults.removeAll()
        
        addResult("Starting SVG String Import", success: true, message: "Processing SVG string")
        
        guard let data = svgString.data(using: .utf8) else {
            addResult("String Conversion Failed", success: false, message: "Could not convert string to data")
            isImporting = false
            return nil
        }
        
        guard let svgDoc = SVGDocument(data) else {
            addResult("SVG Parsing Failed", success: false, message: "Could not parse SVG document")
            isImporting = false
            return nil
        }
        
        addResult("SVG Parsed", success: true, message: "Document size: \(Int(svgDoc.size.width)) × \(Int(svgDoc.size.height))")
        
        // Create VectorDocument from SVG with original data
        let document = createVectorDocumentFromSVG(svgDoc, svgData: data, name: name)
        
        addResult("Import Complete", success: true, message: "Created document with \(document.layers.count) layers")
        isImporting = false
        
        return document
    }
    
    // MARK: - Document Creation
    
    private func createVectorDocumentFromSVG(_ svgDoc: SVGDocument, svgData: Data, name: String = "Imported SVG") -> VectorDocument {
        let svgSize = svgDoc.size
        
        // Create document settings based on SVG size
        let settings = createDocumentSettings(from: svgSize)
        
        // Create main layer for SVG content
        let mainLayer = VectorLayer(
            name: name,
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal
        )
        
        // Extract shapes from SVG (simplified - in real implementation you'd parse SVG elements)
        let shapes = extractShapesFromSVG(svgDoc, svgData: svgData)
        
        // Create document
        let document = VectorDocument(settings: settings)
        document.layers = [mainLayer]
        
        // Add shapes to unified system
        for shape in shapes {
            document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        }
        
        addResult("Shapes Extracted", success: true, message: "Created \(shapes.count) shapes from SVG")
        
        return document
    }
    
    private func createDocumentSettings(from svgSize: CGSize) -> DocumentSettings {
        // Convert SVG size to document settings
        let widthInPoints = svgSize.width
        let heightInPoints = svgSize.height
        
        // Convert to inches (assuming 72 DPI)
        let widthInInches = widthInPoints / 72.0
        let heightInInches = heightInPoints / 72.0
        
        return DocumentSettings(
            width: widthInInches,
            height: heightInInches,
            unit: .inches,
            colorMode: .rgb,
            resolution: 72.0,
            showRulers: true,
            showGrid: false,
            snapToGrid: false,
            gridSpacing: 0.125,
            backgroundColor: .white
        )
    }
    
    private func extractShapesFromSVG(_ svgDoc: SVGDocument, svgData: Data) -> [VectorShape] {
        var shapes: [VectorShape] = []
        let svgSize = svgDoc.size
        
        // Create the original SVG data from the document to use with the existing SVG class
        // We need to reconstruct this or store it from the original import
        addResult("SVG Processing", success: true, message: "Processing SVG with dimensions \(Int(svgSize.width)) × \(Int(svgSize.height))")
        
        // For now, create a shape that represents the SVG content area
        // The actual rendering will be handled by InkPen's canvas system
        let svgContentShape = createSVGContentShape(size: svgSize, document: svgDoc, svgData: svgData)
        shapes.append(svgContentShape)
        
        addResult("SVG Shape Creation", success: true, message: "Created SVG content shape", 
                 details: "Shape will be rendered using CoreSVG when drawn")
        
        return shapes
    }
    
    private func createSVGContentShape(size: CGSize, document: SVGDocument, svgData: Data) -> VectorShape {
        // Create a regular VectorShape with SVG content
        let svgShape = VectorShape(
            name: "[SVG] Content (\(Int(size.width))×\(Int(size.height)))",
            path: VectorPath(elements: [
                .move(to: VectorPoint(0, 0)),
                .line(to: VectorPoint(size.width, 0)),
                .line(to: VectorPoint(size.width, size.height)),
                .line(to: VectorPoint(0, size.height)),
                .close
            ], isClosed: true),
            strokeStyle: StrokeStyle(
                color: .rgb(RGBColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)), 
                width: 2.0,
                placement: .center
            ),
            fillStyle: FillStyle(
                color: .rgb(RGBColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.3))
            ),
            transform: .identity
        )
        
        // Register the SVG data using the shape's ID
        SVGToInkPenImporter.svgShapeRegistry[svgShape.id] = (data: svgData, document: document)
        
        return svgShape
    }
    
    /// Helper method to check if a VectorShape contains SVG content
    static func containsSVGContent(_ shape: VectorShape) -> Bool {
        return svgShapeRegistry[shape.id] != nil || shape.name.hasPrefix("[SVG]")
    }
    
    /// Helper method to get SVG data for a shape
    static func getSVGData(for shape: VectorShape) -> (data: Data, document: SVGDocument)? {
        return svgShapeRegistry[shape.id]
    }
    
    private func convertCGPathToVectorPath(_ cgPath: CGPath) -> VectorPath {
        var elements: [PathElement] = []
        
        cgPath.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(point.x, point.y)))
                
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(point.x, point.y)))
                
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let end = element.points[1]
                elements.append(.quadCurve(to: VectorPoint(end.x, end.y), control: VectorPoint(control.x, control.y)))
                
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let end = element.points[2]
                elements.append(.curve(to: VectorPoint(end.x, end.y), 
                                     control1: VectorPoint(control1.x, control1.y), 
                                     control2: VectorPoint(control2.x, control2.y)))
                
            case .closeSubpath:
                elements.append(.close)
                
            @unknown default:
                break
            }
        }
        
        return VectorPath(elements: elements, isClosed: elements.contains { 
            if case .close = $0 { return true }
            return false
        })
    }
    
    private func createCirclePath(center: VectorPoint, radius: Double) -> VectorPath {
        // Create a circle using cubic bezier curves
        let kappa = 0.5522848 // Magic number for circle approximation
        
        let x = center.x
        let y = center.y
        let r = radius
        
        let elements: [PathElement] = [
            .move(to: VectorPoint(x + r, y)),
            .curve(
                to: VectorPoint(x, y + r),
                control1: VectorPoint(x + r, y + r * kappa),
                control2: VectorPoint(x + r * kappa, y + r)
            ),
            .curve(
                to: VectorPoint(x - r, y),
                control1: VectorPoint(x - r * kappa, y + r),
                control2: VectorPoint(x - r, y + r * kappa)
            ),
            .curve(
                to: VectorPoint(x, y - r),
                control1: VectorPoint(x - r, y - r * kappa),
                control2: VectorPoint(x - r * kappa, y - r)
            ),
            .curve(
                to: VectorPoint(x + r, y),
                control1: VectorPoint(x + r * kappa, y - r),
                control2: VectorPoint(x + r, y - r * kappa)
            ),
            .close
        ]
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Utility Methods
    
    private func addResult(_ operation: String, success: Bool, message: String, details: String = "") {
        DispatchQueue.main.async {
            self.currentOperation = operation
            self.importResults.append(ImportResult(
                operation: operation,
                success: success,
                message: message,
                details: details,
                timestamp: Date()
            ))
        }
    }
    
    // MARK: - Advanced SVG Parsing (Future Enhancement)
    
}

// MARK: - SVG Import View
struct SVGImportView: View {
    @StateObject private var importer = SVGToInkPenImporter()
    @State private var isFilePickerPresented = false
    @State private var importedDocument: VectorDocument?
    @State private var svgString: String = ""
    @State private var showStringInput = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SVG to Ink Pen Importer")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Import SVG files and convert to vector document format")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                Button("Select SVG File") {
                    isFilePickerPresented = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Import SVG String") {
                    showStringInput.toggle()
                }
                .buttonStyle(.bordered)
                
                if importedDocument != nil {
                    Button("Clear") {
                        importedDocument = nil
                        importer.importResults.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if showStringInput {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Paste SVG Content:")
                        .font(.headline)
                    
                    TextEditor(text: $svgString)
                        .frame(height: 150)
                        .border(Color.gray, width: 1)
                        .cornerRadius(4)
                    
                    HStack {
                        Button("Import String") {
                            if !svgString.isEmpty {
                                importedDocument = importer.importSVGString(svgString)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(svgString.isEmpty)
                        
                        Button("Cancel") {
                            showStringInput = false
                            svgString = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            if importer.isImporting {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(importer.currentOperation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            if let document = importedDocument {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Imported Document")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Size: \(Int(document.settings.width)) × \(Int(document.settings.height)) \(document.settings.unit.rawValue)")
                        Text("Layers: \(document.layers.count)")
                        Text("Total Shapes: \(document.unifiedObjects.count)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(importer.importResults) { result in
                        SVGImportResultView(result: result)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 300)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 600)
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
}

struct SVGImportResultView: View {
    let result: SVGToInkPenImporter.ImportResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                
                Text(result.operation)
                    .font(.headline)
                
                Spacer()
                
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(result.message)
                .font(.subheadline)
                .foregroundColor(result.success ? .primary : .red)
            
            if !result.details.isEmpty {
                Text(result.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .shadow(radius: 1)
    }
}

// MARK: - Preview
#Preview {
    SVGImportView()
} 
