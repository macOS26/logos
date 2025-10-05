//
//  GradientHUDWindowDelegate.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import SwiftUI

// MARK: - Gradient HUD Window Delegate to Preserve Position
class GradientHUDWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = GradientHUDWindowDelegate()
    
    private override init() {
        super.init()
    }
    
    // 🔥 INTERCEPT CLOSE BUTTON TO PRESERVE WINDOW POSITION
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Check if this is our gradient HUD window
        if sender.title == "Select Gradient Color" {
            AppState.shared.persistentGradientHUD.stopEditing()
            sender.orderOut(nil)
            return false
        }

        // Check if this is our Ink Color Mixer HUD
        if sender.title == "Ink Color Mixer" {
            AppState.shared.persistentInkHUD.hide()
            sender.orderOut(nil)
            return false
        }

        // Allow normal close behavior for other windows
        return true
    }
}
