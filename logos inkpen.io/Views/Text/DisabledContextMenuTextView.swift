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
        // Draw cursor with normal height but transparent when not editing
        let cursorColor = shouldShowCursor ? color : NSColor.clear
        super.drawInsertionPoint(in: rect, color: cursorColor, turnedOn: flag)
    }

    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        // Always call super to ensure proper text rendering
        // The cursor visibility is controlled in drawInsertionPoint
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }

    // FIXED: Override layout to prevent position jumping
    override func layout() {
        // Ensure layout is consistent across state changes
        layoutManager?.ensureLayout(for: textContainer!)
        super.layout()
    }

    // FIXED: Provide stable intrinsic content size to prevent frame shifts
    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return super.intrinsicContentSize
        }

        // Ensure layout is complete before calculating size
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)

        // Return consistent size based on actual text layout
        return NSSize(width: -1.0, height: ceil(usedRect.height))
    }
}
