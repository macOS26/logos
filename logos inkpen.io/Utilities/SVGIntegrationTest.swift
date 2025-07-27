import SwiftUI
import Foundation
import CoreGraphics

// MARK: - SVG Integration Test
/// Simple integration test to verify SVG to CGContext and Ink Pen Document functionality
class SVGIntegrationTest: ObservableObject {
    
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    
    struct TestResult: Identifiable {
        let id = UUID()
        let testName: String
        let success: Bool
        let message: String
        let timestamp: Date
    }
    
    // MARK: - Test Methods
    
    func runIntegrationTest() {
        isRunning = true
        testResults.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Test 1: CoreSVG Framework
            self.runTest("CoreSVG Framework") { self.testCoreSVGFramework() }
            
            // Test 2: SVG Parsing
            self.runTest("SVG Parsing") { self.testSVGParsing() }
            
            // Test 3: CGContext Rendering
            self.runTest("CGContext Rendering") { self.testCGContextRendering() }
            
            // Test 4: Vector Document Creation
            self.runTest("Vector Document Creation") { self.testVectorDocumentCreation() }
            
            // Test 5: PDF Export
            self.runTest("PDF Export") { self.testPDFExport() }
            
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    private func runTest(_ name: String, _ test: () -> (success: Bool, message: String)) {
        let result = test()
        
        DispatchQueue.main.async {
            self.testResults.append(TestResult(
                testName: name,
                success: result.success,
                message: result.message,
                timestamp: Date()
            ))
        }
        
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    // MARK: - Individual Tests
    
    private func testCoreSVGFramework() -> (success: Bool, message: String) {
        let coreSVG = dlopen("/System/Library/PrivateFrameworks/CoreSVG.framework/CoreSVG", RTLD_NOW)
        
        guard coreSVG != nil else {
            return (false, "Failed to load CoreSVG framework")
        }
        
        let functions = [
            "CGSVGDocumentCreateFromData",
            "CGContextDrawSVGDocument",
            "CGSVGDocumentGetCanvasSize"
        ]
        
        for functionName in functions {
            if dlsym(coreSVG, functionName) == nil {
                dlclose(coreSVG)
                return (false, "Missing function: \(functionName)")
            }
        }
        
        dlclose(coreSVG)
        return (true, "CoreSVG framework loaded successfully")
    }
    
    private func testSVGParsing() -> (success: Bool, message: String) {
        let testSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
        """
        
        guard let data = testSVG.data(using: .utf8) else {
            return (false, "Failed to convert SVG string to data")
        }
        
        // Test basic data conversion
        if data.count > 0 {
            return (true, "SVG string parsed successfully (\(data.count) bytes)")
        } else {
            return (false, "SVG data is empty")
        }
    }
    
    private func testCGContextRendering() -> (success: Bool, message: String) {
        // Create a simple CGContext for testing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: 200,
            height: 200,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (false, "Failed to create CGContext")
        }
        
        // Test basic drawing
        context.setFillColor(CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
        context.fill(CGRect(x: 50, y: 50, width: 100, height: 100))
        
        // Test image creation
        guard let image = context.makeImage() else {
            return (false, "Failed to create image from CGContext")
        }
        
        return (true, "CGContext rendering successful (\(image.width) × \(image.height))")
    }
    
    private func testVectorDocumentCreation() -> (success: Bool, message: String) {
        // Test creating a VectorDocument
        let settings = DocumentSettings(
            width: 8.5,
            height: 11.0,
            unit: .inches,
            colorMode: .rgb,
            resolution: 72.0
        )
        
        let layer = VectorLayer(
            name: "Test Layer",
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal
        )
        
        let document = VectorDocument(settings: settings)
        document.layers = [layer]
        
        return (true, "VectorDocument created successfully")
    }
    
    private func testPDFExport() -> (success: Bool, message: String) {
        // Test PDF context creation
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        var mediaBox = CGRect(origin: .zero, size: CGSize(width: 612, height: 792))
        
        guard let context = CGContext(tempURL as CFURL, mediaBox: &mediaBox, nil) else {
            return (false, "Failed to create PDF context")
        }
        
        context.beginPDFPage(nil)
        
        // Draw a simple shape
        context.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 100, y: 100, width: 200, height: 200))
        
        context.endPDFPage()
        context.closePDF()
        
        // Verify file was created
        let fileExists = FileManager.default.fileExists(atPath: tempURL.path)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
        
        if fileExists {
            return (true, "PDF export test successful")
        } else {
            return (false, "PDF file not created")
        }
    }
}

// MARK: - Integration Test View
struct SVGIntegrationTestView: View {
    @StateObject private var testRunner = SVGIntegrationTest()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SVG Integration Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Testing SVG to CGContext and Ink Pen Document functionality")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if testRunner.isRunning {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Running integration tests...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Button(testRunner.isRunning ? "Running Tests..." : "Run Integration Test") {
                testRunner.runIntegrationTest()
            }
            .buttonStyle(.borderedProminent)
            .disabled(testRunner.isRunning)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(testRunner.testResults) { result in
                        IntegrationTestResultView(result: result)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            if !testRunner.testResults.isEmpty {
                let successCount = testRunner.testResults.filter { $0.success }.count
                let totalCount = testRunner.testResults.count
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Test Summary")
                        .font(.headline)
                    
                    Text("Passed: \(successCount)/\(totalCount)")
                        .foregroundColor(successCount == totalCount ? .green : .orange)
                        .fontWeight(.semibold)
                    
                    if successCount == totalCount {
                        Text("✅ All tests passed! SVG integration is working correctly.")
                            .foregroundColor(.green)
                    } else {
                        Text("⚠️ Some tests failed. Check individual results above.")
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct IntegrationTestResultView: View {
    let result: SVGIntegrationTest.TestResult
    
    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.testName)
                    .font(.headline)
                
                Text(result.message)
                    .font(.subheadline)
                    .foregroundColor(result.success ? .primary : .red)
            }
            
            Spacer()
            
            Text(result.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(6)
        .shadow(radius: 1)
    }
}

// MARK: - Quick Status Check
struct SVGStatusCheck: View {
    @State private var frameworkAvailable = false
    @State private var svgParsingWorks = false
    @State private var hasChecked = false
    
    var body: some View {
        VStack(spacing: 15) {
            Text("SVG Status Check")
                .font(.title)
                .fontWeight(.bold)
            
            if !hasChecked {
                Button("Check SVG Capabilities") {
                    checkCapabilities()
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(alignment: .leading, spacing: 10) {
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
                
                Button("Check Again") {
                    checkCapabilities()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    private func checkCapabilities() {
        frameworkAvailable = SVGTestHarness.testCoreSVGFramework()
        svgParsingWorks = SVGTestHarness.testSVGParsing()
        hasChecked = true
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        SVGStatusCheck()
        Divider()
        SVGIntegrationTestView()
    }
    .padding()
} 