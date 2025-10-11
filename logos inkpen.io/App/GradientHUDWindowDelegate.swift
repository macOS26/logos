import SwiftUI

class GradientHUDWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = GradientHUDWindowDelegate()

    private override init() {
        super.init()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender.title == "Select Gradient Color" {
            AppState.shared.persistentGradientHUD.stopEditing()
            sender.orderOut(nil)
            return false
        }

        if sender.title == "Ink Color Mixer" {
            AppState.shared.persistentInkHUD.hide()
            sender.orderOut(nil)
            return false
        }

        return true
    }
}
