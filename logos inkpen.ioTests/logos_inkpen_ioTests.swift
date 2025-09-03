//
//  logos_inkpen_ioTests.swift
//  logos inkpen.ioTests
//
//  Created by Todd Bruss on 7/13/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io

struct logos_inkpen_ioTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func testDocumentIconGenerator_UnifiedObjectSystem() async throws {
        // Test that DocumentIconGenerator correctly uses unified objects for text detection
        let document = VectorDocument()
        
        // Create a text object as a unified shape with isTextObject = true
        let textShape = VectorShape(
            name: "Test Text",
            path: VectorPath(elements: [], isClosed: false),
            fillStyle: FillStyle(color: VectorColor.black, opacity: 1.0),
            transform: CGAffineTransform(translationX: 100, y: 100),
            isVisible: true,
            isTextObject: true,
            textContent: "Test Text Content",
            typography: TypographyProperties(
                strokeColor: VectorColor.clear,
                fillColor: VectorColor.black
            )
        )
        
        let unifiedObject = VectorObject(shape: textShape, layerIndex: 0, orderID: 0)
        document.unifiedObjects.append(unifiedObject)
        
        // Test the generateInkpenPreview method to verify unified objects are being used
        let iconGenerator = DocumentIconGenerator.shared
        let preview = iconGenerator.generateInkpenPreview(for: document)
        
        // Should contain SVG content with text elements, not empty SVG
        #expect(preview.contains("<svg"), "Should generate SVG content")
        #expect(preview.contains("Test Text Content"), "Should include the text content in SVG")
        
        // The key test: verify the unified object system is being used by checking the SVG contains text
        #expect(preview.contains("<text"), "Should contain text element from unified object")
    }
    
    @Test func testDocumentIconGenerator_EmptyDocument() async throws {
        // Test empty document handling
        let document = VectorDocument()
        let iconGenerator = DocumentIconGenerator.shared
        let preview = iconGenerator.generateInkpenPreview(for: document)
        
        // Should return basic empty SVG (no text or path elements)
        #expect(preview.contains("<svg"), "Should generate SVG content")
        #expect(!preview.contains("<text"), "Empty document should not contain text elements")
        #expect(!preview.contains("<path"), "Empty document should not contain path elements")
    }
    
    @Test func testDocumentIconGenerator_InvisibleTextObjects() async throws {
        // Test that invisible text objects are correctly ignored
        let document = VectorDocument()
        
        // Create an invisible text object as a unified shape
        let invisibleTextShape = VectorShape(
            name: "Hidden Text",
            path: VectorPath(elements: [], isClosed: false),
            fillStyle: FillStyle(color: VectorColor.black, opacity: 1.0),
            transform: CGAffineTransform(translationX: 100, y: 100),
            isVisible: false, // INVISIBLE
            isTextObject: true,
            textContent: "Hidden Text Content",
            typography: TypographyProperties(
                strokeColor: VectorColor.clear,
                fillColor: VectorColor.black
            )
        )
        
        let unifiedObject = VectorObject(shape: invisibleTextShape, layerIndex: 0, orderID: 0)
        document.unifiedObjects.append(unifiedObject)
        
        let iconGenerator = DocumentIconGenerator.shared
        let preview = iconGenerator.generateInkpenPreview(for: document)
        
        // Should return basic empty SVG since text is invisible (no visible content)
        #expect(preview.contains("<svg"), "Should generate SVG content")
        #expect(!preview.contains("<text"), "Document with invisible text should not contain text elements")
        #expect(!preview.contains("Hidden Text Content"), "Hidden text content should not appear in SVG")
    }
}