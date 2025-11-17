import SwiftUI
import AppKit

// MARK: - iPad TODO
// This file uses NSPopover and NSRectEdge which are macOS-only.
// For iPad support, replace with:
// - SwiftUI .popover() modifier, or
// - UIPopoverPresentationController with UIPopoverArrowDirection

/// A popover manager that reuses a single NSPopover instance and smoothly repositions it when the anchor changes
class SlidingPopoverManager: NSObject, NSPopoverDelegate {
    private var popover: NSPopover?
    private var currentAnchorView: NSView?
    private var dismissCallback: (() -> Void)?

    /// Shows the popover or slides it to a new anchor if already visible
    /// - Parameters:
    ///   - content: SwiftUI view to display in the popover
    ///   - anchorView: The view to anchor the popover to
    ///   - edge: Preferred edge for the popover arrow
    ///   - onDismiss: Optional callback when popover is dismissed
    func show<Content: View>(content: Content, anchorView: NSView, edge: Edge = .leading, onDismiss: (() -> Void)? = nil) {
        self.dismissCallback = onDismiss
        if let existingPopover = popover, existingPopover.isShown {
            // Popover is already shown - update content and slide to new anchor
            slideToNewAnchor(anchorView: anchorView, edge: edge, updateContent: {
                if let hostingController = existingPopover.contentViewController as? NSHostingController<Content> {
                    hostingController.rootView = content
                } else {
                    let hostingController = NSHostingController(rootView: content)
                    hostingController.sizingOptions = [.intrinsicContentSize]
                    existingPopover.contentViewController = hostingController
                }
            })
        } else {
            // Create and show new popover with vibrancy
            let hostingController = NSHostingController(rootView: content)
            hostingController.sizingOptions = [.intrinsicContentSize]

            let newPopover = NSPopover()
            newPopover.contentViewController = hostingController
            newPopover.behavior = .transient
            newPopover.animates = true
            newPopover.delegate = self

            // Add vibrancy/translucent effect
            if let popoverView = newPopover.contentViewController?.view {
                popoverView.wantsLayer = true
                popoverView.layer?.backgroundColor = PlatformColor.clear.cgColor
            }

            // Calculate positioning rect and convert Edge to NSRectEdge
            let nsRectEdge = edge.toNSRectEdge()
            let positioningRect = calculatePositioningRect(for: anchorView, edge: nsRectEdge)
            newPopover.show(relativeTo: positioningRect, of: anchorView, preferredEdge: nsRectEdge)

            self.popover = newPopover
            self.currentAnchorView = anchorView
        }
    }

    /// Slides the popover to a new anchor view with animation and optionally updates content
    private func slideToNewAnchor(anchorView: NSView, edge: Edge, updateContent: () -> Void) {
        guard let popover = popover, popover.isShown else { return }

        // Update content first (without recreating the NSPopover)
        updateContent()

        // Animate the position change
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            // Reposition the popover to the new anchor
            let nsRectEdge = edge.toNSRectEdge()
            let positioningRect = calculatePositioningRect(for: anchorView, edge: nsRectEdge)
            popover.show(relativeTo: positioningRect, of: anchorView, preferredEdge: nsRectEdge)
        }

        self.currentAnchorView = anchorView
    }

    /// Calculate tight positioning rect for the given edge
    private func calculatePositioningRect(for anchorView: NSView, edge: NSRectEdge) -> CGRect {
        let bounds = anchorView.bounds

        // Shift positioning rect 17px to the right
        return CGRect(
            x: bounds.origin.x + 17,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )
    }

    /// Dismisses the popover
    func dismiss() {
        // Clear callback BEFORE closing to prevent double-dismiss
        dismissCallback = nil
        popover?.performClose(nil)
        popover = nil
        currentAnchorView = nil
    }

    /// Returns true if the popover is currently shown
    var isShown: Bool {
        return popover?.isShown ?? false
    }

    // MARK: - NSPopoverDelegate

    func popoverWillClose(_ notification: Notification) {
        // Call callback BEFORE close to prevent stale updates
        dismissCallback?()
    }

    func popoverDidClose(_ notification: Notification) {
        dismissCallback = nil
        popover = nil
        currentAnchorView = nil
    }
}

/// Extension to convert SwiftUI Edge to NSRectEdge
extension Edge {
    func toNSRectEdge() -> NSRectEdge {
        switch self {
        case .leading: return .minX
        case .trailing: return .maxX
        case .top: return .maxY
        case .bottom: return .minY
        }
    }
}

/// A reusable glass close button for popovers
struct GlassCloseButton: View {
    let action: () -> Void

    var body: some View {
        if #available(macOS 26.0, *) {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
            }
            .clipShape(.circle)
            .buttonStyle(.glass)
            .glassEffect(.regular, in: .circle)
            .padding(.top, 12)
            .padding(.trailing, 8)
        } else {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.platformWindowBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .buttonStyle(BorderlessButtonStyle())
            .clipShape(Circle())
            .padding(.top, 12)
            .padding(.trailing, 8)
        }
    }
}

/// A view representable that provides an NSView for popover anchoring
struct PopoverAnchorView: NSViewRepresentable {
    let onViewCreated: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.onViewCreated(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }
}
