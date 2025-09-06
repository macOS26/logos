//
//  UnifiedObjectSystemTextUpdateTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemUtilityTests.swift on 1/25/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemTextUpdateTests {
    
    @Test func testUpdateTextContentInUnified() async throws {
        let document = VectorDocument()
        
        let testText = VectorText(
            content: "Original Text",
            typography: TypographyProperties(
                fontFamily: "Arial",
                fontSize: 12.0,
                hasStroke: false,
                strokeColor: VectorColor.black,
                strokeWidth: 1.0,
                strokeOpacity: 1.0,
                fillColor: VectorColor.black,
                fillOpacity: 1.0
            ),
            position: CGPoint(x: 100, y: 100),
            layerIndex: 1
        )
        
        document.addText(testText)
        
        // Verify initial content
        let initialText = document.allTextObjects.first { $0.id == testText.id }
        #expect(initialText?.content == "Original Text", "Initial content not set correctly")
        
        // Use unified helper to update content
        document.updateTextContentInUnified(id: testText.id, content: "Updated Text")
        
        // Verify legacy array updated
        let updatedText = document.allTextObjects.first { $0.id == testText.id }
        #expect(updatedText?.content == "Updated Text", "Legacy textObjects content not updated")
        
        // Verify unified system knows about the text
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        #expect(unifiedExists, "Text not found in unified system")
    }
    
    @Test func testUpdateTextCursorPositionInUnified() async throws {
        let document = VectorDocument()
        
        let testText = VectorText(
            content: "Test Cursor",
            typography: TypographyProperties(
                fontFamily: "Arial",
                fontSize: 12.0,
                hasStroke: false,
                strokeColor: VectorColor.black,
                strokeWidth: 1.0,
                strokeOpacity: 1.0,
                fillColor: VectorColor.black,
                fillOpacity: 1.0
            ),
            position: CGPoint(x: 100, y: 100),
            layerIndex: 1,
            cursorPosition: 0
        )
        
        document.addText(testText)
        
        // Verify initial cursor position
        let initialText = document.allTextObjects.first { $0.id == testText.id }
        #expect(initialText?.cursorPosition == 0, "Initial cursor position not set correctly")
        
        // Use unified helper to update cursor position
        document.updateTextCursorPositionInUnified(id: testText.id, cursorPosition: 5)
        
        // Verify legacy array updated
        let updatedText = document.allTextObjects.first { $0.id == testText.id }
        #expect(updatedText?.cursorPosition == 5, "Legacy textObjects cursor position not updated")
        
        // Verify unified system knows about the text
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        #expect(unifiedExists, "Text not found in unified system")
    }
    
    @Test func testUpdateTextPositionInUnified() async throws {
        let document = VectorDocument()
        
        let testText = VectorText(
            content: "Test Position",
            typography: TypographyProperties(
                fontFamily: "Arial",
                fontSize: 12.0,
                hasStroke: false,
                strokeColor: VectorColor.black,
                strokeWidth: 1.0,
                strokeOpacity: 1.0,
                fillColor: VectorColor.black,
                fillOpacity: 1.0
            ),
            position: CGPoint(x: 100, y: 100),
            layerIndex: 1
        )
        
        document.addText(testText)
        
        // Verify initial position
        let initialText = document.allTextObjects.first { $0.id == testText.id }
        #expect(initialText?.position == CGPoint(x: 100, y: 100), "Initial position not set correctly")
        
        // Use unified helper to update position
        let newPosition = CGPoint(x: 200, y: 300)
        document.updateTextPositionInUnified(id: testText.id, position: newPosition)
        
        // Verify legacy array updated
        let updatedText = document.allTextObjects.first { $0.id == testText.id }
        #expect(updatedText?.position == newPosition, "Legacy textObjects position not updated")
        
        // Verify unified system knows about the text
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        #expect(unifiedExists, "Text not found in unified system")
    }
    
    @Test func testUpdateTextBoundsInUnified() async throws {
        let document = VectorDocument()
        
        let testText = VectorText(
            content: "Test Bounds",
            typography: TypographyProperties(
                fontFamily: "Arial",
                fontSize: 12.0,
                hasStroke: false,
                strokeColor: VectorColor.black,
                strokeWidth: 1.0,
                strokeOpacity: 1.0,
                fillColor: VectorColor.black,
                fillOpacity: 1.0
            ),
            position: CGPoint(x: 100, y: 100),
            layerIndex: 1
        )
        
        document.addText(testText)
        
        // Verify initial bounds (will be auto-calculated)
        let initialText = document.allTextObjects.first { $0.id == testText.id }
        let initialBounds = initialText?.bounds
        #expect(initialBounds != nil, "Initial bounds should be set")
        
        // Use unified helper to update bounds
        let newBounds = CGRect(x: 0, y: 0, width: 200, height: 50)
        document.updateTextBoundsInUnified(id: testText.id, bounds: newBounds)
        
        // Verify legacy array updated
        let updatedText = document.allTextObjects.first { $0.id == testText.id }
        #expect(updatedText?.bounds == newBounds, "Legacy textObjects bounds not updated")
        
        // Verify unified system knows about the text
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        #expect(unifiedExists, "Text not found in unified system")
    }
    
    @Test func testUpdateTextAreaSizeInUnified() async throws {
        let document = VectorDocument()
        
        let testText = VectorText(
            content: "Test Area Size",
            typography: TypographyProperties(
                fontFamily: "Arial",
                fontSize: 12.0,
                hasStroke: false,
                strokeColor: VectorColor.black,
                strokeWidth: 1.0,
                strokeOpacity: 1.0,
                fillColor: VectorColor.black,
                fillOpacity: 1.0
            ),
            position: CGPoint(x: 100, y: 100),
            layerIndex: 1
        )
        
        document.addText(testText)
        
        // Verify initial area size (should be nil for point text)
        let initialText = document.allTextObjects.first { $0.id == testText.id }
        #expect(initialText?.areaSize == nil, "Initial area size should be nil for point text")
        
        // Use unified helper to update area size
        let newAreaSize = CGSize(width: 300, height: 100)
        document.updateTextAreaSizeInUnified(id: testText.id, areaSize: newAreaSize)
        
        // Verify legacy array updated
        let updatedText = document.allTextObjects.first { $0.id == testText.id }
        #expect(updatedText?.areaSize == newAreaSize, "Legacy textObjects area size not updated")
        
        // Verify unified system knows about the text
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        #expect(unifiedExists, "Text not found in unified system")
    }
}