import SwiftUI
import AppKit

/// CTLine-based text editor - renders and edits text using Core Text
/// Uses existing CTLine rendering code from VectorText
struct CTLineTextEditor: NSViewRepresentable {
    let textObject: VectorText
    @Binding var content: String
    @Binding var cursorPosition: Int
    @Binding var isEditing: Bool
    let textBoxWidth: CGFloat?  // If set, enables text box with reflow
    let onCommit: () -> Void

    func makeNSView(context: Context) -> CTLineEditorView {
        let view = CTLineEditorView()
        view.delegate = context.coordinator
        view.typography = textObject.typography
        view.text = content
        view.cursorPosition = cursorPosition
        view.textBoxWidth = textBoxWidth
        return view
    }

    func updateNSView(_ nsView: CTLineEditorView, context: Context) {
        if nsView.text != content {
            nsView.text = content
        }
        if nsView.cursorPosition != cursorPosition {
            nsView.cursorPosition = cursorPosition
        }
        nsView.typography = textObject.typography
        nsView.textBoxWidth = textBoxWidth

        if isEditing && nsView.window?.firstResponder != nsView {
            nsView.window?.makeFirstResponder(nsView)
        } else if !isEditing && nsView.window?.firstResponder == nsView {
            nsView.window?.makeFirstResponder(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CTLineEditorDelegate {
        let parent: CTLineTextEditor

        init(_ parent: CTLineTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ text: String, cursorPosition: Int) {
            parent.content = text
            parent.cursorPosition = cursorPosition
        }

        func editingDidEnd() {
            parent.isEditing = false
            parent.onCommit()
        }
    }
}

// MARK: - CTLine Editor Delegate

protocol CTLineEditorDelegate: AnyObject {
    func textDidChange(_ text: String, cursorPosition: Int)
    func editingDidEnd()
}

// MARK: - CTLine Editor View (NSView)

class CTLineEditorView: NSView {
    weak var delegate: CTLineEditorDelegate?

    var text: String = "" {
        didSet {
            if text != oldValue {
                needsDisplay = true
            }
        }
    }

    var typography: TypographyProperties = TypographyProperties(
        strokeColor: .black,
        fillColor: .black
    ) {
        didSet { needsDisplay = true }
    }

    var textBoxWidth: CGFloat? = nil {
        didSet { needsDisplay = true }
    }

    var cursorPosition: Int = 0 {
        didSet {
            cursorPosition = max(0, min(cursorPosition, text.count))
            needsDisplay = true
        }
    }

    private var showCursor: Bool = true
    private var cursorTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        startCursorBlink()
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        stopCursorBlink()
        delegate?.editingDidEnd()
        needsDisplay = true
        return super.resignFirstResponder()
    }

    // MARK: - Cursor Blinking

    private func startCursorBlink() {
        showCursor = true
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { [weak self] _ in
            self?.showCursor.toggle()
            self?.needsDisplay = true
        }
    }

    private func stopCursorBlink() {
        cursorTimer?.invalidate()
        cursorTimer = nil
        showCursor = false
    }

    // MARK: - Drawing with CTLine (using existing VectorText approach)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Flip coordinate system for CTLine (like PDF export does)
        context.saveGState()
        context.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)

        // Setup text attributes (same as VectorText)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = typography.alignment.nsTextAlignment
        paragraphStyle.lineSpacing = max(0, typography.lineSpacing)
        paragraphStyle.minimumLineHeight = typography.lineHeight
        paragraphStyle.maximumLineHeight = typography.lineHeight

        // Fill color with opacity
        let fillColor = NSColor(cgColor: typography.fillColor.cgColor)?.withAlphaComponent(typography.fillOpacity) ?? NSColor.black

        var attributes: [NSAttributedString.Key: Any] = [
            .font: typography.nsFont,
            .foregroundColor: fillColor,
            .kern: typography.letterSpacing,
            .paragraphStyle: paragraphStyle
        ]

        // Add stroke if enabled
        if typography.hasStroke {
            let strokeColor = NSColor(cgColor: typography.strokeColor.cgColor)?.withAlphaComponent(typography.strokeOpacity) ?? NSColor.black
            attributes[.strokeColor] = strokeColor
            attributes[.strokeWidth] = -typography.strokeWidth  // Negative for fill + stroke
        }

        let displayText = text.isEmpty ? " " : text
        let attributedString = NSAttributedString(string: displayText, attributes: attributes)

        // Check if we're using text box mode
        let useTextBox = textBoxWidth != nil || text.contains("\n") || text.contains("\r")

        if !useTextBox {
            // Single line - use CTLine (like VectorText does)
            let line = CTLineCreateWithAttributedString(attributedString)

            context.textPosition = CGPoint(x: 5, y: bounds.height - 5 - typography.fontSize)
            CTLineDraw(line, context)

            // Draw cursor
            if window?.firstResponder == self && showCursor {
                drawCursor(in: context, line: line, yPosition: bounds.height - 5 - typography.fontSize)
            }
        } else {
            // Text box mode - use CTFrame with constrained width (auto reflow!)
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

            // Use textBoxWidth if set, otherwise use view bounds
            let boxWidth = textBoxWidth ?? bounds.width
            let frameRect = CGRect(x: 5, y: 5, width: boxWidth - 10, height: bounds.height - 10)

            // Draw text box border when editing
            if window?.firstResponder == self {
                context.saveGState()
                context.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor)
                context.setLineWidth(1)
                context.stroke(frameRect)
                context.restoreGState()
            }

            let framePath = CGPath(rect: frameRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), framePath, nil)

            CTFrameDraw(frame, context)

            // Draw cursor for text box
            if window?.firstResponder == self && showCursor {
                drawMultilineCursor(in: context, frame: frame)
            }
        }

        context.restoreGState()
    }

    private func createCoreTextFont() -> CTFont {
        let nsFont = typography.nsFont
        return CTFontCreateWithName(nsFont.fontName as CFString, typography.fontSize, nil)
    }

    private func drawCursor(in context: CGContext, line: CTLine, yPosition: CGFloat) {
        let offset = CTLineGetOffsetForStringIndex(line, cursorPosition, nil)

        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: 5 + offset, y: yPosition))
        context.addLine(to: CGPoint(x: 5 + offset, y: yPosition + typography.fontSize))
        context.strokePath()
        context.restoreGState()
    }

    private func drawMultilineCursor(in context: CGContext, frame: CTFrame) {
        // Find cursor position in multiline text
        guard let lines = CTFrameGetLines(frame) as? [CTLine],
              !lines.isEmpty else { return }

        var lineOrigins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &lineOrigins)

        // Find which line contains cursor
        var charCount = 0
        for (index, line) in lines.enumerated() {
            let lineRange = CTLineGetStringRange(line)
            let lineLength = lineRange.length

            if cursorPosition <= charCount + lineLength {
                let offset = CTLineGetOffsetForStringIndex(line, cursorPosition, nil)
                let origin = lineOrigins[index]

                context.saveGState()
                context.setStrokeColor(NSColor.controlAccentColor.cgColor)
                context.setLineWidth(2)
                context.move(to: CGPoint(x: 5 + origin.x + offset, y: origin.y))
                context.addLine(to: CGPoint(x: 5 + origin.x + offset, y: origin.y + typography.fontSize))
                context.strokePath()
                context.restoreGState()
                break
            }

            charCount += lineLength
        }
    }

    // MARK: - Keyboard Input

    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else { return }

        switch event.keyCode {
        case 51: // Delete (Backspace)
            if cursorPosition > 0 {
                let index = text.index(text.startIndex, offsetBy: cursorPosition - 1)
                text.remove(at: index)
                cursorPosition -= 1
                delegate?.textDidChange(text, cursorPosition: cursorPosition)
            }

        case 117: // Forward delete
            if cursorPosition < text.count {
                let index = text.index(text.startIndex, offsetBy: cursorPosition)
                text.remove(at: index)
                delegate?.textDidChange(text, cursorPosition: cursorPosition)
            }

        case 123: // Left arrow
            cursorPosition = max(0, cursorPosition - 1)

        case 124: // Right arrow
            cursorPosition = min(text.count, cursorPosition + 1)

        case 125: // Down arrow
            moveCursorDown()

        case 126: // Up arrow
            moveCursorUp()

        case 36: // Return/Enter
            if event.modifierFlags.contains(.command) {
                // Cmd+Return = finish editing
                window?.makeFirstResponder(nil)
            } else {
                // Regular return = newline
                insertText("\n")
            }

        case 48: // Tab
            insertText("\t")

        case 53: // Escape
            window?.makeFirstResponder(nil)

        default:
            // Insert character
            insertText(characters)
        }

        needsDisplay = true
    }

    private func insertText(_ string: String) {
        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        text.insert(contentsOf: string, at: index)
        cursorPosition += string.count
        delegate?.textDidChange(text, cursorPosition: cursorPosition)
    }

    private func moveCursorDown() {
        // Simple implementation - find next newline
        if let nextNewline = text[text.index(text.startIndex, offsetBy: cursorPosition)...].firstIndex(of: "\n") {
            cursorPosition = text.distance(from: text.startIndex, to: nextNewline) + 1
        } else {
            cursorPosition = text.count
        }
    }

    private func moveCursorUp() {
        // Simple implementation - find previous newline
        if cursorPosition > 0,
           let prevNewline = text[..<text.index(text.startIndex, offsetBy: cursorPosition)].lastIndex(of: "\n") {
            cursorPosition = text.distance(from: text.startIndex, to: prevNewline)
        } else {
            cursorPosition = 0
        }
    }

    // MARK: - Mouse Click (position cursor)

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Create CTLine/CTFrame to find string index from click
        let attributes: [NSAttributedString.Key: Any] = [
            .font: typography.nsFont,
            .kern: typography.letterSpacing
        ]
        let attributedString = NSAttributedString(string: text.isEmpty ? " " : text, attributes: attributes)

        if !text.contains("\n") && !text.contains("\r") {
            // Single line
            let line = CTLineCreateWithAttributedString(attributedString)
            let clickX = point.x - 5
            let index = CTLineGetStringIndexForPosition(line, CGPoint(x: clickX, y: 0))
            cursorPosition = min(index, text.count)
        } else {
            // Multiline - find clicked line
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            let framePath = CGPath(rect: bounds.insetBy(dx: 5, dy: 5), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), framePath, nil)

            if let lines = CTFrameGetLines(frame) as? [CTLine] {
                var lineOrigins = [CGPoint](repeating: .zero, count: lines.count)
                CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &lineOrigins)

                for (index, line) in lines.enumerated() {
                    let origin = lineOrigins[index]
                    if point.y >= origin.y && point.y <= origin.y + typography.fontSize {
                        let clickX = point.x - 5 - origin.x
                        let stringIndex = CTLineGetStringIndexForPosition(line, CGPoint(x: clickX, y: 0))
                        cursorPosition = min(stringIndex, text.count)
                        break
                    }
                }
            }
        }

        needsDisplay = true

        if window?.firstResponder != self {
            window?.makeFirstResponder(self)
        }
    }
}
