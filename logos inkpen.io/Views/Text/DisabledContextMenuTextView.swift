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
    var shouldShowCursor: Bool = true

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

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        // Draw the cursor with transparent color when not editing
        // This keeps the layout consistent while hiding the cursor visually
        let cursorColor = shouldShowCursor ? color : NSColor.clear
        super.drawInsertionPoint(in: rect, color: cursorColor, turnedOn: flag)
    }

    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        // Always call super to ensure proper text rendering
        // The cursor visibility is controlled in drawInsertionPoint
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }
}
