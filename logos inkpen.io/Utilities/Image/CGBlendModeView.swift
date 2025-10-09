//
//  CGBlendModeView.swift
//  logos inkpen.io
//
//  SwiftUI extension to use full CGBlendMode via NSViewRepresentable
//

import SwiftUI
import AppKit

// MARK: - NSView with CGBlendMode Support
class BlendModeNSView: NSView {
    var blendMode: CGBlendMode = .normal
    var contentView: NSView?

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Set blend mode
        context.setBlendMode(blendMode)

        // Draw subviews with blend mode applied
        super.draw(dirtyRect)
    }

    override var isFlipped: Bool { true }
}

// MARK: - NSViewRepresentable Wrapper
struct CGBlendModeContainer<Content: View>: NSViewRepresentable {
    let blendMode: CGBlendMode
    let content: Content

    func makeNSView(context: Context) -> BlendModeNSView {
        let blendView = BlendModeNSView()
        blendView.blendMode = blendMode

        // Create hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        blendView.addSubview(hostingView)

        // Pin hosting view to blend view
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: blendView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: blendView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: blendView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: blendView.bottomAnchor)
        ])

        blendView.contentView = hostingView

        return blendView
    }

    func updateNSView(_ nsView: BlendModeNSView, context: Context) {
        nsView.blendMode = blendMode
        nsView.needsDisplay = true

        // Update content
        if let hostingView = nsView.contentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

// MARK: - SwiftUI View Extension
extension View {
    /// Apply a CGBlendMode to this view using NSViewRepresentable
    /// This gives access to ALL CGBlendMode modes, not just SwiftUI's subset
    func cgBlendMode(_ mode: CGBlendMode) -> some View {
        CGBlendModeContainer(blendMode: mode, content: self)
    }

    /// Apply a BlendMode enum to this view using CGBlendMode rendering
    /// This allows using ALL BlendMode cases, even those not supported by SwiftUI
    func cgBlendMode(_ mode: BlendMode) -> some View {
        CGBlendModeContainer(blendMode: mode.cgBlendMode, content: self)
    }
}
