import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Cross-Platform Popover Manager
/// A popover manager that reuses a single popover instance and repositions it when the anchor changes
/// Works on both macOS (NSPopover) and iOS/iPadOS (UIPopoverPresentationController)
class SlidingPopoverManager: NSObject {
    #if os(macOS)
    private var popover: NSPopover?
    private var currentAnchorView: NSView?
    #else
    private var popoverController: UIViewController?
    private var currentAnchorView: UIView?
    private weak var presentingViewController: UIViewController?
    #endif

    private var dismissCallback: (() -> Void)?

    /// Shows the popover or slides it to a new anchor if already visible
    /// - Parameters:
    ///   - content: SwiftUI view to display in the popover
    ///   - anchorView: The view to anchor the popover to
    ///   - edge: Preferred edge for the popover arrow
    ///   - onDismiss: Optional callback when popover is dismissed
    #if os(macOS)
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
    #else
    func show<Content: View>(content: Content, anchorView: UIView, edge: Edge = .leading, onDismiss: (() -> Void)? = nil) {
        self.dismissCallback = onDismiss

        // Find the presenting view controller from the anchor view
        if presentingViewController == nil {
            presentingViewController = anchorView.viewController
        }

        guard let presentingVC = presentingViewController else { return }

        if let existingController = popoverController, existingController.presentingViewController != nil {
            // Popover is already shown - update content and reposition to new anchor
            if let hostingController = existingController as? UIHostingController<Content> {
                hostingController.rootView = content
            } else {
                // Different content type - dismiss and re-present
                existingController.dismiss(animated: false) {
                    self.showNewPopover(content: content, anchorView: anchorView, edge: edge, presentingVC: presentingVC)
                }
                return
            }

            // Update popover presentation to new anchor
            if let popover = existingController.popoverPresentationController {
                popover.sourceView = anchorView
                popover.sourceRect = calculatePositioningRect(for: anchorView, edge: edge)
                popover.permittedArrowDirections = edge.toUIPopoverArrowDirection()
            }

            self.currentAnchorView = anchorView
        } else {
            // Show new popover
            showNewPopover(content: content, anchorView: anchorView, edge: edge, presentingVC: presentingVC)
        }
    }

    private func showNewPopover<Content: View>(content: Content, anchorView: UIView, edge: Edge, presentingVC: UIViewController) {
        let hostingController = UIHostingController(rootView: content)
        hostingController.modalPresentationStyle = .popover

        if let popover = hostingController.popoverPresentationController {
            popover.sourceView = anchorView
            popover.sourceRect = calculatePositioningRect(for: anchorView, edge: edge)
            popover.permittedArrowDirections = edge.toUIPopoverArrowDirection()
            popover.delegate = self
        }

        presentingVC.present(hostingController, animated: true)
        self.popoverController = hostingController
        self.currentAnchorView = anchorView
    }
    #endif

    #if os(macOS)
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
    #else
    /// Calculate tight positioning rect for the given edge
    private func calculatePositioningRect(for anchorView: UIView, edge: Edge) -> CGRect {
        let bounds = anchorView.bounds

        // Shift positioning rect 17px to the right (same behavior as macOS)
        return CGRect(
            x: bounds.origin.x + 17,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )
    }
    #endif

    /// Dismisses the popover
    func dismiss() {
        // Clear callback BEFORE closing to prevent double-dismiss
        dismissCallback = nil
        #if os(macOS)
        popover?.performClose(nil)
        popover = nil
        #else
        popoverController?.dismiss(animated: true)
        popoverController = nil
        #endif
        currentAnchorView = nil
    }

    /// Returns true if the popover is currently shown
    var isShown: Bool {
        #if os(macOS)
        return popover?.isShown ?? false
        #else
        return popoverController?.presentingViewController != nil
        #endif
    }
}

// MARK: - macOS Delegate
#if os(macOS)
extension SlidingPopoverManager: NSPopoverDelegate {
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
#else
// MARK: - iOS Delegate
extension SlidingPopoverManager: UIPopoverPresentationControllerDelegate {
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        // Call callback BEFORE dismiss to prevent stale updates
        dismissCallback?()
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        dismissCallback = nil
        popoverController = nil
        currentAnchorView = nil
    }
}
#endif

// MARK: - Edge Conversion Extensions
#if os(macOS)
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
#else
/// Extension to convert SwiftUI Edge to UIPopoverArrowDirection
extension Edge {
    func toUIPopoverArrowDirection() -> UIPopoverArrowDirection {
        switch self {
        case .leading: return .left
        case .trailing: return .right
        case .top: return .up
        case .bottom: return .down
        }
    }
}

/// Helper extension to find UIViewController from UIView
extension UIView {
    var viewController: UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
}
#endif

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

// MARK: - Cross-Platform Anchor View
#if os(macOS)
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
#else
/// A view representable that provides a UIView for popover anchoring
struct PopoverAnchorView: UIViewRepresentable {
    let onViewCreated: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            self.onViewCreated(view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}
#endif
