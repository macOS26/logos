//
//  PersistentGradientHUDManager.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import Combine

@Observable
class PersistentGradientHUDManager {
    // 🔥 PERSISTENT STATE - Never recreated
    var isVisible = false
    var isDragging = false
    private var isHiding = false // 🔥 NEW: Prevent multiple hide calls
    
    // Reference to AppState for window management
    private weak var appState: AppState?
    
    // 🔥 POSITION HANDLED BY NSWindow - No manual tracking needed
    
    // Current gradient stop data - updates WITHOUT recreating the HUD
    var editingStopId: UUID? = nil
    var editingStopColor: VectorColor = .black
    var currentDocument: VectorDocument? = nil
    var currentGradient: VectorGradient? = nil
    var onColorSelected: ((UUID, VectorColor) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    
    // Single stable document for ColorPanel - NEVER recreated
    private var stableColorDocument = VectorDocument()
    
    init(appState: AppState) {
        self.appState = appState
        // Don't set to black - this affects ALL documents via ColorManager.shared!
    }
    
    func show(stopId: UUID, color: VectorColor, document: VectorDocument, gradient: VectorGradient?, 
              onColorSelected: @escaping (UUID, VectorColor) -> Void, onClose: @escaping () -> Void) {
        // 🔥 FIXED: Reset hiding flag when showing
        isHiding = false
        
        // Remember if window was already visible to avoid reopening
        
        // Update state WITHOUT recreating anything
        self.editingStopId = stopId
        self.editingStopColor = color
        self.currentDocument = document
        self.currentGradient = gradient
        self.onColorSelected = onColorSelected
        self.onClose = onClose
        
        // Update the stable document color - this triggers ColorPanel refresh
        stableColorDocument.defaultFillColor = color
        
        // 🔥 CRITICAL: Force the ColorPanel to refresh when switching gradient stops
        stableColorDocument.objectWillChange.send()
        
        // 🔥 ALWAYS set visible, but only trigger window opening once
        isVisible = true
        
        var foundExistingWindow = false
        
        for window in NSApplication.shared.windows {
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "gradient-hud") {
                
                if !window.isVisible {
                    // 🔥 NEW: Safe window positioning
                    safeShowWindow(window)
                }
                foundExistingWindow = true
                break // Exit the loop once we find the gradient window
            }
        }
        
        // Only open a new window if we didn't find an existing one
        if !foundExistingWindow {
            appState?.openWindowAction?("gradient-hud")
        }
        
        // If already visible, the WindowGroup will automatically update the content
    }
    
    func hide() {
        NSApplication.shared.windows.forEach { window in
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "gradient-hud"), window.isVisible {
                // 🔥 USE orderOut INSTEAD OF close TO PRESERVE WINDOW POSITION
                // This hides the window without destroying it, so position is maintained
                window.orderOut(nil)
            }
        }
    }
    
    // 🔥 NEW: Stop editing when window is closed with X button
    func stopEditing() {
        isVisible = false
        editingStopId = nil
        editingStopColor = .black
        currentDocument = nil
        currentGradient = nil
        onColorSelected = nil
        onClose = nil
        
        // Clear the stable document color (don't set to black - affects all documents!)
        // stableColorDocument.defaultFillColor = .black
        stableColorDocument.objectWillChange.send()
        
        // Call the onClose callback if it exists
        onClose?()
        
    }
    
    // 🔥 EMERGENCY RESET: Force reset hiding flag
    func forceResetHidingFlag() {
        isHiding = false
    }
    
    // 🔥 DEBUG: Count gradient windows
    func countGradientWindows() -> Int {
        let count = NSApplication.shared.windows.filter { window in
            window.title.contains("Gradient Color Picker")
        }.count
        return count
    }
    
    func updateStopColor(_ stopId: UUID, _ color: VectorColor) {
        // Update our tracking
        if stopId == editingStopId {
            editingStopColor = color
            stableColorDocument.defaultFillColor = color
            
            // 🔥 CRITICAL: Force the ColorPanel to refresh with the new color
            stableColorDocument.objectWillChange.send()
        }
        
        // Call the callback to update the actual gradient
        onColorSelected?(stopId, color)
    }
    
    func getStableDocument() -> VectorDocument {
        return stableColorDocument
    }
    
    // 🔥 NEW: Display validation to prevent invalid display identifier errors
    private func validateDisplayForWindow() -> Bool {
        // Check if we have valid displays
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return false
        }
        
        // Check if main display is valid
        guard let mainScreen = NSScreen.main else {
            return false
        }
        
        // Validate display frame
        let frame = mainScreen.frame
        guard frame.width > 0 && frame.height > 0 && 
              !frame.origin.x.isNaN && !frame.origin.y.isNaN &&
              !frame.width.isNaN && !frame.height.isNaN else {
            return false
        }
        
        return true
    }
    
    // 🔥 NEW: Safe window showing with error handling
    private func safeShowWindow(_ window: NSWindow) {
        // Set window properties safely
        window.tabbingMode = .disallowed
        
        // Validate window position before showing
        let currentFrame = window.frame
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        
        if let screen = mainScreen {
            let screenFrame = screen.visibleFrame
            
            // Ensure window is within screen bounds
            var newFrame = currentFrame
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
            
            if newFrame != currentFrame {
                window.setFrame(newFrame, display: false)
            }
        }
        
        // Show window
        window.makeKeyAndOrderFront(nil)
    }
} 

// MARK: - Persistent Ink HUD Manager (for Ink Color Mixer)

@Observable
class PersistentInkHUDManager {
    var isVisible = false
    private weak var appState: AppState?
    
    // The document whose colors are being edited
    var currentDocument: VectorDocument? = nil
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func show(document: VectorDocument) {
        currentDocument = document
        isVisible = true
        
        // 🔥 NEW: Validate display before showing window
        if !validateDisplayForInkHUD() {
            // Continue with fallback positioning
        }
        
        var foundExistingWindow = false
        for window in NSApplication.shared.windows {
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "ink-hud") {
                if !window.isVisible {
                    // 🔥 NEW: Safe window positioning
                    safeShowInkHUDWindow(window)
                }
                foundExistingWindow = true
                break
            }
        }
        
        if !foundExistingWindow {
            appState?.openWindowAction?("ink-hud")
        }
    }
    
    func hide() {
        NSApplication.shared.windows.forEach { window in
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "ink-hud"), window.isVisible {
                window.orderOut(nil)
            }
        }
        isVisible = false
    }
    
    // 🔥 NEW: Display validation for Ink HUD
    private func validateDisplayForInkHUD() -> Bool {
        // Check if we have valid displays
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return false
        }
        
        // Check if main display is valid
        guard let mainScreen = NSScreen.main else {
            return false
        }
        
        // Validate display frame
        let frame = mainScreen.frame
        guard frame.width > 0 && frame.height > 0 && 
              !frame.origin.x.isNaN && !frame.origin.y.isNaN &&
              !frame.width.isNaN && !frame.height.isNaN else {
            return false
        }
        
        return true
    }
    
    // 🔥 NEW: Safe window showing for Ink HUD
    private func safeShowInkHUDWindow(_ window: NSWindow) {
        // Set window properties safely
        window.tabbingMode = .disallowed
        
        // Validate window position before showing
        let currentFrame = window.frame
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        
        if let screen = mainScreen {
            let screenFrame = screen.visibleFrame
            
            // Ensure window is within screen bounds
            var newFrame = currentFrame
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
            
            if newFrame != currentFrame {
                window.setFrame(newFrame, display: false)
            }
        }
        
        // Show window
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Gradient Editing State

struct GradientEditingState {
    let gradientId: UUID // ID to track which gradient is being edited
    let stopIndex: Int   // Which color stop is being edited
    let onColorSelected: (VectorColor) -> Void // Callback when color is selected
    
    init(gradientId: UUID, stopIndex: Int, onColorSelected: @escaping (VectorColor) -> Void) {
        self.gradientId = gradientId
        self.stopIndex = stopIndex
        self.onColorSelected = onColorSelected
    }
}

struct GradientHUDData {
    let document: VectorDocument
    let editingGradientStopId: UUID?
    let editingGradientStopColor: VectorColor
    let currentGradient: VectorGradient?
    let updateStopColor: (UUID, VectorColor) -> Void
    let turnOffEditingState: () -> Void
}
