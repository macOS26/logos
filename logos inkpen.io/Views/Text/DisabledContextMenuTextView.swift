import AppKit

class DisabledContextMenuTextView: NSTextView {
    var allowsInteraction: Bool = true
    var shouldShowCursor: Bool = true
    var pendingClickLocation: CGPoint?

    // Force cursor redraw when insertionPointColor changes
    override var insertionPointColor: NSColor? {
        didSet {
            if let layoutManager = layoutManager,
               let textContainer = textContainer {
                let glyphRange = layoutManager.glyphRange(for: textContainer)
                if glyphRange.length > 0 {
                    let charIndex = selectedRange().location
                    if charIndex < layoutManager.numberOfGlyphs {
                        let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: charIndex, length: 0), in: textContainer)
                        setNeedsDisplay(rect, avoidAdditionalLayout: true)
                    }
                }
            }
        }
    }

    override var wantsDefaultClipping: Bool {
        return false
    }

    override func draw(_ dirtyRect: NSRect) {
        let extendedRect = dirtyRect.insetBy(dx: -10, dy: -10)
        super.draw(extendedRect)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }

    override func rightMouseDown(with event: NSEvent) {
    }

    override func mouseDown(with event: NSEvent) {
        if allowsInteraction {
            super.mouseDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        if allowsInteraction {
            let result = super.becomeFirstResponder()

            // If we have a pending click location, position cursor there
            if let clickLocation = pendingClickLocation, let layoutManager = layoutManager, let textContainer = textContainer {
                layoutManager.ensureLayout(for: textContainer)
                let characterIndex = layoutManager.characterIndex(for: clickLocation, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
                let validIndex = max(0, min(string.count, characterIndex))
                setSelectedRange(NSRange(location: validIndex, length: 0))
                pendingClickLocation = nil
            }

            return result
        }
        return false
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        let cursorColor = shouldShowCursor ? color : NSColor.clear
        var thickerRect = rect
        thickerRect.size.width = 1.0
        super.drawInsertionPoint(in: thickerRect, color: cursorColor, turnedOn: flag)
    }
}
