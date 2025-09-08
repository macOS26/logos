//
//  UnifiedObjectSystemHelperMethodTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemTests.swift on 1/25/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemHelperMethodTests {
    
    @Test func testLockTextInUnified() async throws {
        let document = VectorDocument()
        
        // Create test text
        let testText = VectorText(
            content: "Test Lock",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 100, y: 100)
        )
        
        // Add to document and unified system
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Verify initially unlocked
        let initialText = document.getAllTextObjects().first { $0.id == testText.id }
        #expect(initialText?.isLocked == false)
        let initialUnifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        if case .shape(let shape) = initialUnifiedShape?.objectType {
            #expect(shape.isLocked == false)
        }
        
        // Use unified helper to lock
        document.lockTextInUnified(id: testText.id)
        
        // Verify text is locked in unified system
        let lockedText = document.getAllTextObjects().first { $0.id == testText.id }
        #expect(lockedText?.isLocked == true, "Text not locked in unified system")
        
        let lockedUnifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        if case .shape(let shape) = lockedUnifiedShape?.objectType {
            #expect(shape.isLocked == true, "Unified objects array not updated")
        }
    }
    
    @Test func testUnlockTextInUnified() async throws {
        let document = VectorDocument()
        
        // Create test text (start locked)
        let testText = VectorText(
            content: "Test Unlock",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 100, y: 100),
            isLocked: true
        )
        
        // Add to document and unified system
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Use unified helper to unlock
        document.unlockTextInUnified(id: testText.id)
        
        // Verify text is unlocked in unified system
        let unlockedText = document.getAllTextObjects().first { $0.id == testText.id }
        #expect(unlockedText?.isLocked == false, "Text not unlocked in unified system")
        
        let unlockedUnifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        if case .shape(let shape) = unlockedUnifiedShape?.objectType {
            #expect(shape.isLocked == false, "Unified objects array not updated")
        }
    }
    
    @Test func testHideTextInUnified() async throws {
        let document = VectorDocument()
        
        // Create test text
        let testText = VectorText(
            content: "Test Hide",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 100, y: 100)
        )
        
        // Add to document and unified system
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Verify initially visible
        let initialVisibleText = document.getAllTextObjects().first { $0.id == testText.id }
        #expect(initialVisibleText?.isVisible == true)
        
        // Use unified helper to hide
        document.hideTextInUnified(id: testText.id)
        
        // Verify text is hidden in unified system
        let hiddenText = document.getAllTextObjects().first { $0.id == testText.id }
        #expect(hiddenText?.isVisible == false, "Text not hidden in unified system")
        
        let hiddenUnifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        if case .shape(let shape) = hiddenUnifiedShape?.objectType {
            #expect(shape.isVisible == false, "Unified objects array not updated")
        }
    }
    
    @Test func testShowTextInUnified() async throws {
        let document = VectorDocument()
        
        // Create test text (start hidden)
        let testText = VectorText(
            content: "Test Show",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 100, y: 100),
            isVisible: false
        )
        
        // Add to document and unified system
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Use unified helper to show
        document.showTextInUnified(id: testText.id)
        
        // Verify text is visible in unified system
        let visibleText = document.getAllTextObjects().first { $0.id == testText.id }
        #expect(visibleText?.isVisible == true, "Text not visible in unified system")
        
        let visibleUnifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        if case .shape(let shape) = visibleUnifiedShape?.objectType {
            #expect(shape.isVisible == true, "Unified objects array not updated")
        }
    }
    
}
