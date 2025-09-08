//
//  UnifiedTextLockUnlockMigrationTests.swift
//  logos inkpen.ioTests
//
//  Testing migration of lock/unlock text methods to eliminate layers[].shapes
//

import Testing
@testable import logos_inkpen_io
import Foundation
import CoreGraphics

@Suite("Unified Text Lock/Unlock Migration Tests")
struct UnifiedTextLockUnlockMigrationTests {
    
    @Test("lockTextInUnified and unlockTextInUnified work correctly")
    func testLockUnlockText() {
        let document = VectorDocument()
        
        // Create a text object
        let textObject = VectorText(
            content: "Lockable Text",
            position: CGPoint(x: 100, y: 100),
            typography: Typography(
                fontFamily: "Arial",
                fontSize: 18
            )
        )
        
        // Add text through unified system
        document.addText(textObject, to: 0)
        
        // Verify initial state - should be unlocked
        if let addedText = document.findText(by: textObject.id) {
            #expect(addedText.isLocked == false, "Text should initially be unlocked")
        } else {
            Issue.record("Text not found after adding")
        }
        
        // Lock the text
        document.lockTextInUnified(id: textObject.id)
        
        // Verify text is locked in unified system
        let lockedUnifiedText = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, shape.id == textObject.id {
                return shape
            }
            return nil
        }.first
        
        #expect(lockedUnifiedText?.isLocked == true, "Text should be locked in unified objects")
        
        // Verify text is locked when retrieved
        if let lockedText = document.findText(by: textObject.id) {
            #expect(lockedText.isLocked == true, "Text should be locked")
        } else {
            Issue.record("Text not found after locking")
        }
        
        // Unlock the text
        document.unlockTextInUnified(id: textObject.id)
        
        // Verify text is unlocked in unified system
        let unlockedUnifiedText = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, shape.id == textObject.id {
                return shape
            }
            return nil
        }.first
        
        #expect(unlockedUnifiedText?.isLocked == false, "Text should be unlocked in unified objects")
        
        // Verify text is unlocked when retrieved
        if let unlockedText = document.findText(by: textObject.id) {
            #expect(unlockedText.isLocked == false, "Text should be unlocked")
        } else {
            Issue.record("Text not found after unlocking")
        }
    }
    
    @Test("Lock/unlock preserves typography")
    func testLockUnlockPreservesTypography() {
        let document = VectorDocument()
        
        // Create text with specific typography
        let textObject = VectorText(
            content: "Typography Test",
            position: CGPoint(x: 50, y: 50),
            typography: Typography(
                fontFamily: "Times New Roman",
                fontSize: 36,
                fontWeight: .semibold,
                fontStyle: .normal,
                alignment: .right,
                fillColor: .solid(color: CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
            )
        )
        
        document.addText(textObject, to: 0)
        
        // Lock and then unlock
        document.lockTextInUnified(id: textObject.id)
        document.unlockTextInUnified(id: textObject.id)
        
        // Verify typography is preserved
        if let text = document.findText(by: textObject.id) {
            #expect(text.typography.fontFamily == "Times New Roman", "Font family should be preserved")
            #expect(text.typography.fontSize == 36, "Font size should be preserved")
            #expect(text.typography.fontWeight == .semibold, "Font weight should be preserved")
            #expect(text.typography.fontStyle == .normal, "Font style should be preserved")
            #expect(text.typography.alignment == .right, "Alignment should be preserved")
            
            // Verify color was preserved
            if case .solid(let color) = text.typography.fillColor {
                let components = color.components ?? []
                if components.count >= 3 {
                    #expect(abs(components[0] - 0.5) < 0.01, "Red should be preserved")
                    #expect(abs(components[1] - 0.5) < 0.01, "Green should be preserved")
                    #expect(abs(components[2] - 0.5) < 0.01, "Blue should be preserved")
                }
            }
        } else {
            Issue.record("Text not found after lock/unlock")
        }
    }
}
