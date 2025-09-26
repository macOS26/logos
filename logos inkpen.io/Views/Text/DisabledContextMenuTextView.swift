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
    
    // CRITICAL: Store initial text container insets to maintain consistency
    private var fixedTextContainerInset = NSSize(width: 0, height: 0)
    private var fixedLineFragmentPadding: CGFloat = 0

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
        // CRITICAL: Store current position before becoming first responder
        let currentOrigin = frame.origin
        
        // Only allow becoming first responder when interaction is allowed
        if allowsInteraction {
            let result = super.becomeFirstResponder()
            // CRITICAL: Restore position if it changed
            if frame.origin != currentOrigin {
                self.setFrameOrigin(currentOrigin)
            }
            return result
        }
        return false
    }
    
    override func resignFirstResponder() -> Bool {
        // CRITICAL: Store current position before resigning first responder
        let currentOrigin = frame.origin
        let result = super.resignFirstResponder()
        
        // CRITICAL: Restore position if it changed
        if frame.origin != currentOrigin {
            self.setFrameOrigin(currentOrigin)
        }
        
        return result
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        // CRITICAL: Use a fixed cursor rect to prevent layout shifts
        // Always use 30% height cursor to maintain consistent text baseline
        var adjustedRect = rect
        adjustedRect.size.height = rect.size.height * 0.3
        
        // Draw cursor with normal height but transparent when not editing
        let cursorColor = shouldShowCursor ? color : NSColor.clear
        super.drawInsertionPoint(in: adjustedRect, color: cursorColor, turnedOn: flag)
    }

    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        // Always call super to ensure proper text rendering
        // The cursor visibility is controlled in drawInsertionPoint
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }

    // FIXED: Override layout to prevent position jumping
    override func layout() {
        // CRITICAL: Maintain fixed insets during layout
        self.textContainerInset = fixedTextContainerInset
        self.textContainer?.lineFragmentPadding = fixedLineFragmentPadding
        
        // Ensure layout is consistent across state changes
        layoutManager?.ensureLayout(for: textContainer!)
        super.layout()
        
        // CRITICAL: Re-apply fixed insets after layout
        self.textContainerInset = fixedTextContainerInset
        self.textContainer?.lineFragmentPadding = fixedLineFragmentPadding
    }

    // FIXED: Provide stable intrinsic content size to prevent frame shifts
    override var intrinsicContentSize: NSSize {
        // CRITICAL: Return NO intrinsic size to let the frame be controlled externally
        // This prevents NSTextView from trying to resize itself
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    // FIXED: Prevent vertical shift when becoming first responder
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        // Maintain consistent origin to prevent jumping
        super.setFrameOrigin(newOrigin)
    }

    // FIXED: Ensure consistent text container setup
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
        // CRITICAL: Always maintain consistent text container insets
        self.textContainerInset = fixedTextContainerInset
        self.textContainer?.lineFragmentPadding = fixedLineFragmentPadding
    }
    
    // CRITICAL: Override to prevent automatic adjustment of text container origin
    override var textContainerOrigin: NSPoint {
        // Always return zero to maintain consistent text position
        return NSPoint.zero
    }
}