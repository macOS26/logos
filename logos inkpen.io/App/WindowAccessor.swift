import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowAccessorView(callback: callback)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }
}

/// Custom view that calls back immediately when added to window hierarchy
private class WindowAccessorView: NSView {
    private let callback: (NSWindow?) -> Void
    private var hasCalledBack = false

    init(callback: @escaping (NSWindow?) -> Void) {
        self.callback = callback
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Call immediately when window is available, not async
        if !hasCalledBack, let window = self.window {
            hasCalledBack = true
            callback(window)
        }
    }
}
