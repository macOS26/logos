import SwiftUI
import AppKit

// MARK: - Star Tool HUD Window
class StarToolHUDWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure as HUD window - child window doesn't need floating level
        self.level = .normal
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.isMovable = false
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}

// MARK: - Star Tool HUD Manager
class StarToolHUDManager: ObservableObject {
    private var hudWindow: StarToolHUDWindow?
    @Published var selectedVariant: StarVariant = .fivePoint
    var starButtonFrame: CGRect = .zero
    
    func showHUD() {
        guard starButtonFrame != .zero else {
            print("⭐ Cannot show HUD - no button frame")
            return
        }
        
        hideHUD() // Hide any existing HUD first
        
        // Create new HUD window
        hudWindow = StarToolHUDWindow()
        
        // Create SwiftUI content
        let hudContent = StarVariantHUDView(
            selectedVariant: Binding(
                get: { self.selectedVariant },
                set: { self.selectedVariant = $0 }
            ),
            onSelection: { [weak self] variant in
                self?.selectedVariant = variant
                self?.hideHUD()
            }
        )
        
        // Host SwiftUI content in NSHostingView
        let hostingView = NSHostingView(rootView: hudContent)
        hudWindow?.contentView = hostingView
        
        // SOLUTION: Make HUD a child window of the main window
        // This keeps it contained within our app and gives us the same coordinate system!
        if let mainWindow = NSApplication.shared.mainWindow {
            mainWindow.addChildWindow(hudWindow!, ordered: .above)
            print("⭐ HUD added as child window to main window")
        } else {
            print("⭐ Warning: No main window found - HUD will float independently")
        }
        
        // COORDINATE SYSTEM FACTS (from Apple documentation):
        // - SwiftUI .global coordinates on macOS: Origin at BOTTOM-LEFT (AppKit style)
        // - Child window coordinates: SAME as parent window (main window coordinates)
        // - Therefore: NO CONVERSION NEEDED - we're in the same coordinate space!
        
        let hudWidth: CGFloat = 200
        let hudHeight: CGFloat = 40
        let gapBetweenToolbarAndHUD: CGFloat = 4
        
        print("⭐ SwiftUI global frame: \(starButtonFrame)")
        print("⭐ Button center: (\(starButtonFrame.midX), \(starButtonFrame.midY))")
        
        // DETAILED DEBUGGING: Capture ALL coordinate information
        let screenHeight = NSScreen.main?.frame.height ?? 800
        let mainWindow = NSApplication.shared.mainWindow
        let windowFrame = mainWindow?.frame ?? NSRect.zero
        
        print("=== COMPLETE COORDINATE DEBUG ===")
        print("⭐ Screen: \(NSScreen.main?.frame ?? NSRect.zero)")
        print("⭐ Window: \(windowFrame)")
        print("⭐ Button frame (SwiftUI global): \(starButtonFrame)")
        print("⭐ Button minX: \(starButtonFrame.minX), maxX: \(starButtonFrame.maxX)")
        print("⭐ Button minY: \(starButtonFrame.minY), maxY: \(starButtonFrame.maxY), midY: \(starButtonFrame.midY)")
        print("⭐ Screen height: \(screenHeight)")
        
        // TEST MULTIPLE POSITIONING APPROACHES
        let approach1_Y = screenHeight - starButtonFrame.maxY
        let approach2_Y = screenHeight - starButtonFrame.minY  
        let approach3_Y = screenHeight - starButtonFrame.midY
        let approach4_Y = starButtonFrame.minY
        let approach5_Y = starButtonFrame.maxY
        let approach6_Y = starButtonFrame.midY
        
        print("⭐ Y Approach 1 (screen - maxY): \(approach1_Y)")
        print("⭐ Y Approach 2 (screen - minY): \(approach2_Y)")
        print("⭐ Y Approach 3 (screen - midY): \(approach3_Y)")
        print("⭐ Y Approach 4 (raw minY): \(approach4_Y)")
        print("⭐ Y Approach 5 (raw maxY): \(approach5_Y)")
        print("⭐ Y Approach 6 (raw midY): \(approach6_Y)")
        
        // TEST X POSITIONING - try button's actual right edge
        let buttonRightEdge = starButtonFrame.maxX
        print("⭐ Button right edge: \(buttonRightEdge)")
        print("⭐ Proposed X position: \(buttonRightEdge + gapBetweenToolbarAndHUD)")
        
        // THE ISSUE: SwiftUI global coordinates ARE flipped relative to NSWindow!
        // SwiftUI: origin top-left, Y increases downward
        // NSWindow: origin bottom-left, Y increases upward
        // So we DO need coordinate conversion!
        let hudFrame = NSRect(
            x: buttonRightEdge + gapBetweenToolbarAndHUD, // X is correct: 44.0
            y: approach1_Y - (hudHeight / 2), // USE APPROACH 1: screen - maxY = proper conversion
            width: hudWidth,
            height: hudHeight
        )
        
        print("⭐ HUD frame: \(hudFrame)")
        
        hudWindow?.setFrame(hudFrame, display: true)
        hudWindow?.orderFront(nil)
        hudWindow?.makeKey()
    }
    
    func hideHUD() {
        if let window = hudWindow {
            // Remove from parent window if it's a child window
            if let parentWindow = window.parent {
                parentWindow.removeChildWindow(window)
                print("⭐ HUD removed from parent window")
            }
            window.orderOut(nil)
        }
        hudWindow = nil
    }
}

// MARK: - SwiftUI HUD Content
struct StarVariantHUDView: View {
    @Binding var selectedVariant: StarVariant
    let onSelection: (StarVariant) -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(StarVariant.allCases, id: \.self) { variant in
                Button {
                    onSelection(variant)
                    print("⭐ HUD: Selected star variant: \(variant.rawValue)")
                } label: {
                    variant.iconView(
                        isSelected: selectedVariant == variant,
                        color: selectedVariant == variant ? .white : .primary
                    )
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selectedVariant == variant ? Color.blue : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help(variant.rawValue.capitalized)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.9))
                .shadow(radius: 8)
        )
    }
}