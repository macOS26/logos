//
//  UnifiedObjectSystemToolbarTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemHelperMethodTests.swift on 1/25/25.
//

// import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemToolbarTests {
    
    @Test func testMainToolbarLockUnlockMigration() async throws {
        let document = VectorDocument()
        
        // Create test texts
        let testText1 = VectorText(
            content: "Test 1",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 50, y: 50)
        )
        let testText2 = VectorText(
            content: "Test 2", 
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 100, y: 100)
        )
        
        // Add to document
        document.addTextToUnifiedSystem(testText1, layerIndex: 1)
        document.addTextToUnifiedSystem(testText2, layerIndex: 1)
        
        // Select and lock like MainToolbarContent does
        document.selectedObjectIDs.insert(testText1.id)
        document.lockTextInUnified(id: testText1.id)
        
        // Verify only selected text is locked
        let lockedText = document.allTextObjects.first { $0.id == testText1.id }
        let unlockedText = document.allTextObjects.first { $0.id == testText2.id }
        
        #expect(lockedText?.isLocked == true, "Selected text should be locked via unified helper")
        #expect(unlockedText?.isLocked == false, "Unselected text should remain unlocked")
        
        // Test unlock all functionality
        for textObject in document.getAllTextObjects() {
            document.unlockTextInUnified(id: textObject.id)
        }
        
        // Verify all unlocked
        for textObject in document.getAllTextObjects() {
            #expect(textObject.isLocked == false, "All text should be unlocked via unified helpers")
        }
    }
    
    @Test func testMainToolbarHideShowMigration() async throws {
        let document = VectorDocument()
        
        // Create test texts
        let testText1 = VectorText(
            content: "Hide Test",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 50, y: 50)
        )
        let testText2 = VectorText(
            content: "Show Test",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 100, y: 100)
        )
        
        // Add to document
        document.addTextToUnifiedSystem(testText1, layerIndex: 1)
        document.addTextToUnifiedSystem(testText2, layerIndex: 1)
        
        // Select and hide like MainToolbarContent does
        document.selectedObjectIDs.insert(testText1.id)
        document.hideTextInUnified(id: testText1.id)
        
        // Verify only selected text is hidden
        let hiddenText = document.allTextObjects.first { $0.id == testText1.id }
        let visibleText = document.allTextObjects.first { $0.id == testText2.id }
        
        #expect(hiddenText?.isVisible == false, "Selected text should be hidden via unified helper")
        #expect(visibleText?.isVisible == true, "Unselected text should remain visible")
        
        // Test show all functionality
        for textObject in document.getAllTextObjects() {
            document.showTextInUnified(id: textObject.id)
        }
        
        // Verify all visible
        for textObject in document.getAllTextObjects() {
            #expect(textObject.isVisible == true, "All text should be visible via unified helpers")
        }
    }
    
    @Test func testUpdateTextFillOpacityInUnified() async throws {
        let document = VectorDocument()
        
        // Create test text
        let testText = VectorText(
            content: "Opacity Test",
            typography: TypographyProperties(
                strokeColor: VectorColor.black,
                fillColor: VectorColor.black,
                fillOpacity: 0.5
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        // Add to document and unified system
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Use unified helper to update opacity
        let newOpacity = 0.8
        document.updateTextFillOpacityInUnified(id: testText.id, opacity: newOpacity)
        
        // Verify both arrays updated
        let updatedText = document.allTextObjects.first { $0.id == testText.id }
        #expect(updatedText?.typography.fillOpacity == newOpacity, "Legacy textObjects opacity not updated")
        
        let updatedUnifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        if case .shape(let shape) = updatedUnifiedShape?.objectType {
            #expect(shape.typography?.fillOpacity == newOpacity, "Unified objects opacity not updated")
        }
    }
    
    @Test func testUpdateTextStrokeWidthInUnified() async throws {
        let document = VectorDocument()
        
        // Create test text
        let testText = VectorText(
            content: "Stroke Test",
            typography: TypographyProperties(
                strokeColor: VectorColor.black,
                strokeWidth: 1.0,
                fillColor: VectorColor.black
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        // Add to document and unified system
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Use unified helper to update stroke width
        let newWidth = 3.0
        document.updateTextStrokeWidthInUnified(id: testText.id, width: newWidth)
        
        // Verify both arrays updated
        let updatedText = document.allTextObjects.first { $0.id == testText.id }
        #expect(updatedText?.typography.strokeWidth == newWidth, "Legacy textObjects stroke width not updated")
        #expect(updatedText?.typography.hasStroke == true, "Legacy textObjects hasStroke not updated")
        
        let updatedUnifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        if case .shape(let shape) = updatedUnifiedShape?.objectType {
            #expect(shape.typography?.strokeWidth == newWidth, "Unified objects stroke width not updated")
            #expect(shape.typography?.hasStroke == true, "Unified objects hasStroke not updated")
        }
        
        // Test setting stroke width to 0 (should disable stroke)
        document.updateTextStrokeWidthInUnified(id: testText.id, width: 0.0)
        
        let noStrokeText = document.allTextObjects.first { $0.id == testText.id }
        #expect(noStrokeText?.typography.hasStroke == false, "hasStroke should be false when width is 0")
    }
}