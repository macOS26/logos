//
//  DisabledContextMenuTextView.swift
//  logos inkpen.io
//
//  Custom NSTextView with disabled context menu
//

import AppKit

// MARK: - Custom NSTextView with Disabled Context Menu
class DisabledContextMenuTextView: NSTextView {
    var allowsInteraction: Bool = true

    override func menu(for event: NSEvent) -> NSMenu? {
        // Return nil to completely disable the context menu
        return nil
    }

    override func rightMouseDown(with event: NSEvent) {
        // Consume right mouse events to prevent context menu
        // Don't call super to prevent the default context menu
    }

    override func mouseDown(with event: NSEvent) {
        // Only allow mouse down (which makes it first responder) when interaction is allowed
        if allowsInteraction {
            super.mouseDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        // Only allow becoming first responder when interaction is allowed
        if allowsInteraction {
            return super.becomeFirstResponder()
        }
        return false
    }
}
