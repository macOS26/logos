import XCTest
import CoreGraphics
import PDFKit
@testable import logos_inkpen_io

class PDFGradientExportTests: XCTestCase {
    
    func testPDFExportWithMultiStopGradient() throws {
        // Create a document with 1024x1024 dimensions
        let document = VectorDocument()
        document.settings.sizeInPoints = CGSize(width: 1024, height: 1024)
        
        // Create a gradient with 11 stops (like the rainbow gradient)
        let gradientStops = [
            GradientStop(position: 0.0, color: .rgb(RGBColor(red: 0.929, green: 0.110, blue: 0.141, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.1, color: .rgb(RGBColor(red: 0.860, green: 0.148, blue: 0.197, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.2, color: .rgb(RGBColor(red: 0.776, green: 0.200, blue: 0.269, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.3, color: .rgb(RGBColor(red: 0.693, green: 0.254, blue: 0.341, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.4, color: .rgb(RGBColor(red: 0.601, green: 0.310, blue: 0.416, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.5, color: .rgb(RGBColor(red: 0.507, green: 0.368, blue: 0.500, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.6, color: .rgb(RGBColor(red: 0.412, green: 0.426, blue: 0.581, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.7, color: .rgb(RGBColor(red: 0.313, green: 0.485, blue: 0.666, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.8, color: .rgb(RGBColor(red: 0.208, green: 0.552, blue: 0.756, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.9, color: .rgb(RGBColor(red: 0.106, green: 0.617, blue: 0.847, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.682, blue: 0.937, alpha: 1.0)), opacity: 1.0)
        ]
        
        let linearGradient = LinearGradient(
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 1, y: 0),
            stops: gradientStops,
            angle: 90.0
        )
        
        // Create a shape with the gradient
        let path = VectorPath(elements: [
            .move(to: VectorPoint(x: 100, y: 100)),
            .line(to: VectorPoint(x: 924, y: 100)),
            .line(to: VectorPoint(x: 924, y: 924)),
            .line(to: VectorPoint(x: 100, y: 924)),
            .close
        ])
        
        let shape = VectorShape(
            path: path,
            fillStyle: FillStyle(color: .gradient(.linear(linearGradient)), opacity: 1.0),
            strokeStyle: nil
        )
        
        // Add shape to document
        document.unifiedObjects.append(shape)
        
        // Generate PDF data
        let pdfData = try FileOperations.generatePDFData(from: document)
        
        // Verify PDF was created
        XCTAssertFalse(pdfData.isEmpty, "PDF data should not be empty")
        
        // Parse the PDF to verify it contains gradient (not rasterized)
        if let pdfDocument = PDFDocument(data: pdfData) {
            XCTAssertEqual(pdfDocument.pageCount, 1, "PDF should have one page")
            
            if let page = pdfDocument.page(at: 0) {
                let pageBounds = page.bounds(for: .mediaBox)
                XCTAssertEqual(pageBounds.width, 1024, accuracy: 1.0, "PDF width should be 1024")
                XCTAssertEqual(pageBounds.height, 1024, accuracy: 1.0, "PDF height should be 1024")
                
                // Check that the PDF contains shading operators (sh command)
                if let pageData = page.dataRepresentation {
                    let pdfString = String(data: pageData, encoding: .utf8) ?? ""
                    
                    // Look for shading operator which indicates vector gradient
                    XCTAssertTrue(
                        pdfString.contains("/Sh") || pdfString.contains("sh"),
                        "PDF should contain shading operators for vector gradients"
                    )
                    
                    // Should NOT contain inline image data (which would indicate rasterization)
                    XCTAssertFalse(
                        pdfString.contains("BI") && pdfString.contains("ID") && pdfString.contains("EI"),
                        "PDF should not contain inline images (gradients should be vector)"
                    )
                }
            }
        } else {
            XCTFail("Failed to create PDFDocument from data")
        }
    }
    
    func testPDFGradientInterpolation() throws {
        // Test that gradient interpolation works correctly
        let stops = [
            GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.5, color: .rgb(RGBColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)), opacity: 1.0)
        ]
        
        let gradient = LinearGradient(
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 1, y: 0),
            stops: stops
        )
        
        // Create shading function
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let shadingFunction = FileOperations.createShadingFunction(for: gradient, colorSpace: colorSpace)
        
        XCTAssertNotNil(shadingFunction, "Shading function should be created successfully")
    }
    
    func testRadialGradientPDFExport() throws {
        // Create a document with radial gradient
        let document = VectorDocument()
        document.settings.sizeInPoints = CGSize(width: 512, height: 512)
        
        let radialGradient = RadialGradient(
            centerPoint: CGPoint(x: 0.5, y: 0.5),
            radius: 0.5,
            stops: [
                GradientStop(position: 0.0, color: .white, opacity: 1.0),
                GradientStop(position: 1.0, color: .black, opacity: 1.0)
            ]
        )
        
        let path = VectorPath(elements: [
            .move(to: VectorPoint(x: 56, y: 56)),
            .line(to: VectorPoint(x: 456, y: 56)),
            .line(to: VectorPoint(x: 456, y: 456)),
            .line(to: VectorPoint(x: 56, y: 456)),
            .close
        ])
        
        let shape = VectorShape(
            path: path,
            fillStyle: FillStyle(color: .gradient(.radial(radialGradient)), opacity: 1.0),
            strokeStyle: nil
        )
        
        document.unifiedObjects.append(shape)
        
        // Generate PDF data
        let pdfData = try FileOperations.generatePDFData(from: document)
        
        // Verify PDF was created with correct size
        XCTAssertFalse(pdfData.isEmpty, "PDF data should not be empty")
        
        if let pdfDocument = PDFDocument(data: pdfData) {
            if let page = pdfDocument.page(at: 0) {
                let pageBounds = page.bounds(for: .mediaBox)
                XCTAssertEqual(pageBounds.width, 512, accuracy: 1.0, "PDF width should be 512")
                XCTAssertEqual(pageBounds.height, 512, accuracy: 1.0, "PDF height should be 512")
            }
        }
    }
}