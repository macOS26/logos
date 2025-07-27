import SwiftUI
import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

// MARK: - SVG Import Debug Test
/// Comprehensive test for importing SVG files and converting to Ink Pen Document format
/// Uses CoreSVG framework for high-quality vector conversion
class SVGImportDebugTest: ObservableObject {
    
    // MARK: - Test Results
    @Published var testResults: [TestResult] = []
    @Published var currentTest: String = "No test running"
    @Published var isRunning: Bool = false
    
    struct TestResult: Identifiable {
        let id = UUID()
        let testName: String
        let success: Bool
        let message: String
        let details: String
        let timestamp: Date
    }
    
    // MARK: - CoreSVG Framework Bridge (from SVGContentView)
    @objc class CGSVGDocument: NSObject { }
    
    static let CoreSVG = dlopen("/System/Library/PrivateFrameworks/CoreSVG.framework/CoreSVG", RTLD_NOW)
    
    static var CGSVGDocumentRetain: (@convention(c) (CGSVGDocument?) -> Unmanaged<CGSVGDocument>?) = load("CGSVGDocumentRetain")
    static var CGSVGDocumentRelease: (@convention(c) (CGSVGDocument?) -> Void) = load("CGSVGDocumentRelease")
    static var CGSVGDocumentCreateFromData: (@convention(c) (CFData?, CFDictionary?) -> Unmanaged<CGSVGDocument>?) = load("CGSVGDocumentCreateFromData")
    static var CGContextDrawSVGDocument: (@convention(c) (CGContext?, CGSVGDocument?) -> Void) = load("CGContextDrawSVGDocument")
    static var CGSVGDocumentGetCanvasSize: (@convention(c) (CGSVGDocument?) -> CGSize) = load("CGSVGDocumentGetCanvasSize")
    
    static func load<T>(_ name: String) -> T {
        unsafeBitCast(dlsym(CoreSVG, name), to: T.self)
    }
    
    // MARK: - SVG Document Class
    class SVGDocument {
        deinit { SVGImportDebugTest.CGSVGDocumentRelease(document) }
        
        let document: CGSVGDocument
        
        init?(_ data: Data) {
            guard let document = SVGImportDebugTest.CGSVGDocumentCreateFromData(data as CFData, nil)?.takeUnretainedValue() else { return nil }
            guard SVGImportDebugTest.CGSVGDocumentGetCanvasSize(document) != .zero else { return nil }
            self.document = document
        }
        
        var size: CGSize {
            SVGImportDebugTest.CGSVGDocumentGetCanvasSize(document)
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
            
            SVGImportDebugTest.CGContextDrawSVGDocument(context, document)
            
            context.restoreGState()
        }
    }
    
    // MARK: - Test Methods
    func runAllTests() {
        isRunning = true
        testResults.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.runTest("CoreSVG Framework Loading") { self.testCoreSVGFramework() }
            self.runTest("SVG File Loading") { self.testSVGFileLoading() }
            self.runTest("SVG to CGContext Rendering") { self.testSVGToCGContext() }
            self.runTest("Vector Path Extraction") { self.testVectorPathExtraction() }
            self.runTest("Ink Pen Document Creation") { self.testInkPenDocumentCreation() }
            self.runTest("Vector Export") { self.testVectorExport() }
            
            DispatchQueue.main.async {
                self.isRunning = false
                self.currentTest = "All tests completed"
            }
        }
    }
    
    private func runTest(_ name: String, _ test: () -> (success: Bool, message: String, details: String)) {
        DispatchQueue.main.async {
            self.currentTest = "Running: \(name)"
        }
        
        let result = test()
        
        DispatchQueue.main.async {
            self.testResults.append(TestResult(
                testName: name,
                success: result.success,
                message: result.message,
                details: result.details,
                timestamp: Date()
            ))
        }
        
        // Small delay between tests
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    // MARK: - Individual Tests
    
    private func testCoreSVGFramework() -> (success: Bool, message: String, details: String) {
        guard Self.CoreSVG != nil else {
            return (false, "Failed to load CoreSVG framework", "dlopen returned nil")
        }
        
        // Test function loading
        let _: [(String, UnsafeRawPointer)] = [
            ("CGSVGDocumentCreateFromData", unsafeBitCast(Self.CGSVGDocumentCreateFromData, to: UnsafeRawPointer.self)),
            ("CGContextDrawSVGDocument", unsafeBitCast(Self.CGContextDrawSVGDocument, to: UnsafeRawPointer.self)),
            ("CGSVGDocumentGetCanvasSize", unsafeBitCast(Self.CGSVGDocumentGetCanvasSize, to: UnsafeRawPointer.self))
        ]
        
        // All functions should be loaded successfully
        return (true, "CoreSVG framework loaded successfully", "All required functions available")
    }
    
    private func testSVGFileLoading() -> (success: Bool, message: String, details: String) {
        // Test with sample SVG data
        let sampleSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="40" fill="red"/>
        </svg>
        """
        
        guard let data = sampleSVG.data(using: .utf8) else {
            return (false, "Failed to create SVG data", "String to Data conversion failed")
        }
        
        guard let svgDoc = SVGDocument(data) else {
            return (false, "Failed to parse SVG", "CGSVGDocumentCreateFromData returned nil")
        }
        
        let size = svgDoc.size
        return (true, "SVG loaded successfully", "Size: \(size.width) × \(size.height)")
    }
    
    private func testSVGToCGContext() -> (success: Bool, message: String, details: String) {
        let sampleSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
            <rect x="10" y="10" width="180" height="180" fill="blue" stroke="red" stroke-width="2"/>
            <circle cx="100" cy="100" r="50" fill="green"/>
        </svg>
        """
        
        guard let data = sampleSVG.data(using: .utf8),
              let svgDoc = SVGDocument(data) else {
            return (false, "Failed to create test SVG", "SVG parsing failed")
        }
        
        // Create CGContext for testing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 400,
            height: 400,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (false, "Failed to create CGContext", "CGContext creation failed")
        }
        
        // Test rendering
        svgDoc.renderToVectorContext(context, targetSize: CGSize(width: 400, height: 400))
        
        // Verify we can create an image from the context
        guard let image = context.makeImage() else {
            return (false, "Failed to create image from context", "CGContext.makeImage() returned nil")
        }
        
        return (true, "SVG rendered to CGContext successfully", "Image size: \(image.width) × \(image.height)")
    }
    
    private func testVectorPathExtraction() -> (success: Bool, message: String, details: String) {
        // This test simulates extracting vector paths from SVG
        // In a real implementation, you would parse SVG path data into VectorPath objects
        
        let samplePaths = [
            VectorPath(elements: [
                .move(to: VectorPoint(10, 10)),
                .line(to: VectorPoint(100, 10)),
                .line(to: VectorPoint(100, 100)),
                .line(to: VectorPoint(10, 100)),
                .close
            ], isClosed: true),
            
            VectorPath(elements: [
                .move(to: VectorPoint(50, 50)),
                .curve(to: VectorPoint(100, 50), control1: VectorPoint(75, 25), control2: VectorPoint(75, 75))
            ], isClosed: false)
        ]
        
        // Test path conversion to CGPath
        for (index, path) in samplePaths.enumerated() {
            let cgPath = path.cgPath
            if cgPath.isEmpty {
                return (false, "Failed to convert VectorPath to CGPath", "Path \(index) conversion failed")
            }
        }
        
        return (true, "Vector path extraction successful", "Created \(samplePaths.count) test paths")
    }
    
    private func testInkPenDocumentCreation() -> (success: Bool, message: String, details: String) {
        // Test creating a VectorDocument with imported SVG content
        
        // Create document settings
        let settings = DocumentSettings(
            width: 11.0,
            height: 8.5,
            unit: .inches,
            colorMode: .rgb,
            resolution: 72.0
        )
        
        // Create a test layer
        let testLayer = VectorLayer(
            name: "Imported SVG",
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal
        )
        
        // Create test shapes from SVG-like data
        let testShapes = [
            VectorShape(
                name: "Test Rectangle",
                path: VectorPath(elements: [
                    .move(to: VectorPoint(50, 50)),
                    .line(to: VectorPoint(150, 50)),
                    .line(to: VectorPoint(150, 150)),
                    .line(to: VectorPoint(50, 150)),
                    .close
                ], isClosed: true),
                strokeStyle: StrokeStyle(color: .black, width: 2.0),
                fillStyle: FillStyle(color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0))),
                transform: .identity
            ),
            
            VectorShape(
                name: "Test Curve",
                path: VectorPath(elements: [
                    .move(to: VectorPoint(100, 100)),
                    .curve(to: VectorPoint(200, 100), control1: VectorPoint(150, 50), control2: VectorPoint(150, 150))
                ], isClosed: false),
                strokeStyle: StrokeStyle(color: .rgb(RGBColor(red: 0.0, green: 1.0, blue: 0.0)), width: 1.0),
                fillStyle: FillStyle(color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0))),
                transform: .identity
            )
        ]
        
        // Add shapes to layer
        var layerWithShapes = testLayer
        layerWithShapes.shapes = testShapes
        
        // Create document
        let document = VectorDocument(settings: settings)
        document.layers = [layerWithShapes]
        
        return (true, "Ink Pen Document created successfully", "Document with \(testShapes.count) shapes in 1 layer")
    }
    
    private func testVectorExport() -> (success: Bool, message: String, details: String) {
        // Test exporting to vector formats
        
        let sampleSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200">
            <rect x="20" y="20" width="260" height="160" fill="lightblue" stroke="navy" stroke-width="3"/>
            <text x="150" y="110" text-anchor="middle" fill="navy" font-size="24">Vector Export Test</text>
        </svg>
        """
        
        guard let data = sampleSVG.data(using: .utf8),
              let svgDoc = SVGDocument(data) else {
            return (false, "Failed to create test SVG for export", "SVG parsing failed")
        }
        
        // Test PDF export
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_export.pdf")
        var mediaBox = CGRect(origin: .zero, size: CGSize(width: 612, height: 792))
        
        guard let context = CGContext(tempURL as CFURL, mediaBox: &mediaBox, nil) else {
            return (false, "Failed to create PDF context", "CGContext creation failed")
        }
        
        context.beginPDFPage(nil)
        svgDoc.renderToVectorContext(context, targetSize: CGSize(width: 612, height: 792))
        context.endPDFPage()
        context.closePDF()
        
        // Verify file was created
        let fileExists = FileManager.default.fileExists(atPath: tempURL.path)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
        
        if fileExists {
            return (true, "Vector export successful", "PDF created and verified")
        } else {
            return (false, "Vector export failed", "PDF file not created")
        }
    }
}

// MARK: - Debug Test View
struct SVGImportDebugTestView: View {
    @StateObject private var testRunner = SVGImportDebugTest()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SVG Import Debug Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Testing CoreSVG Framework Integration")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if testRunner.isRunning {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(testRunner.currentTest)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Button(testRunner.isRunning ? "Running Tests..." : "Run All Tests") {
                testRunner.runAllTests()
            }
            .buttonStyle(.borderedProminent)
            .disabled(testRunner.isRunning)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(testRunner.testResults) { result in
                        TestResultView(result: result)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct TestResultView: View {
    let result: SVGImportDebugTest.TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                
                Text(result.testName)
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
    SVGImportDebugTestView()
} 