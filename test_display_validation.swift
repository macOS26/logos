#!/usr/bin/env swift

import AppKit
import Foundation

// Test script to validate display handling and diagnose display identifier issues
print("🖥️ Testing Display Validation...")

class DisplayValidator {
    static func validateDisplays() {
        let screens = NSScreen.screens
        print("📊 Found \(screens.count) displays:")
        
        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let isValid = frame.width > 0 && frame.height > 0 && 
                         !frame.origin.x.isNaN && !frame.origin.y.isNaN &&
                         !frame.width.isNaN && !frame.height.isNaN
            
            print("   Display \(index):")
            print("     Frame: \(frame)")
            print("     Visible Frame: \(visibleFrame)")
            print("     Valid: \(isValid ? "✅" : "❌")")
            
            if !isValid {
                print("     ⚠️  Invalid display frame detected!")
            }
        }
        
        // Test main screen
        if let mainScreen = NSScreen.main {
            print("📱 Main Screen: \(mainScreen.frame)")
        } else {
            print("❌ No main screen available")
        }
    }
    
    static func testWindowPositioning() {
        print("\n🪟 Testing Window Positioning...")
        
        guard let mainScreen = NSScreen.main else {
            print("❌ Cannot test window positioning - no main screen")
            return
        }
        
        let screenFrame = mainScreen.visibleFrame
        print("📐 Screen visible frame: \(screenFrame)")
        
        // Test window positioning logic
        let testWindowFrame = CGRect(x: 100, y: 100, width: 300, height: 200)
        print("🧪 Test window frame: \(testWindowFrame)")
        
        // Check if window is within screen bounds
        let isWithinBounds = screenFrame.intersects(testWindowFrame)
        print("📍 Window within bounds: \(isWithinBounds ? "✅" : "❌")")
        
        if !isWithinBounds {
            // Calculate safe position
            var newFrame = testWindowFrame
            if newFrame.maxX > screenFrame.maxX {
                newFrame.origin.x = screenFrame.maxX - newFrame.width
            }
            if newFrame.maxY > screenFrame.maxY {
                newFrame.origin.y = screenFrame.maxY - newFrame.height
            }
            if newFrame.minX < screenFrame.minX {
                newFrame.origin.x = screenFrame.minX
            }
            if newFrame.minY < screenFrame.minY {
                newFrame.origin.y = screenFrame.minY
            }
            print("🔧 Safe position: \(newFrame)")
        }
    }
    
    static func monitorDisplayChanges() {
        print("\n👀 Setting up display change monitoring...")
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { notification in
            print("🔄 Display configuration changed!")
            validateDisplays()
        }
        
        print("✅ Display monitoring active (press Ctrl+C to stop)")
        
        // Keep the script running to monitor for changes
        RunLoop.main.run()
    }
}

// Run the tests
DisplayValidator.validateDisplays()
DisplayValidator.testWindowPositioning()

// Check command line arguments
if CommandLine.arguments.contains("--monitor") {
    DisplayValidator.monitorDisplayChanges()
} else {
    print("\n💡 Run with --monitor to watch for display changes")
    print("💡 Example: swift test_display_validation.swift --monitor")
}
