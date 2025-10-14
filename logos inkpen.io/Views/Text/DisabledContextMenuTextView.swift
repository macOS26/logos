import AppKit

class DisabledContextMenuTextView: NSTextView {
    var allowsInteraction: Bool = true
    var shouldShowCursor: Bool = true

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
            return super.becomeFirstResponder()
        }
        return false
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        let cursorColor = shouldShowCursor ? color : NSColor.clear
        var thickerRect = rect
        thickerRect.size.width = 1.0
        super.drawInsertionPoint(in: thickerRect, color: cursorColor, turnedOn: flag)
    }

    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }
}
