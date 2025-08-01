import SwiftUI
import AppKit

// MARK: - Star Tool HUD Window
class StarToolHUDWindow: NSWindow {
    weak var hudManager: StarToolHUDManager?
    private var clickOutsideMonitor: Any?
    
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
        
        // Set up click-outside monitoring
        setupClickOutsideMonitoring()
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    private func setupClickOutsideMonitoring() {
        // Monitor for clicks outside the HUD window
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            
            // Get the mouse location in screen coordinates
            let mouseLocation = NSEvent.mouseLocation
            
            // Check if the click is outside our HUD window
            if !self.frame.contains(mouseLocation) {
                print("⭐ Click detected outside HUD - closing")
                DispatchQueue.main.async {
                    self.hudManager?.hideHUD()
                }
            }
        }
    }
    
    deinit {
        // Clean up the event monitor
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
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
        hudWindow?.hudManager = self // Set reference for click-outside monitoring
        
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
            x: buttonRightEdge + gapBetweenToolbarAndHUD - 8 + 4, // X moved left by 8px for padding, then right 4px: 40.0
            y: approach1_Y - (hudHeight / 2) - 8 + 4 - 1, // USE APPROACH 1: screen - maxY = proper conversion, lowered by 8px for padding, then up 4px, then down 1px
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
    
    // Computed property to reorder variants with selected variant first
    private var orderedVariants: [StarVariant] {
        var variants = StarVariant.allCases
        // Move selected variant to the front
        if let selectedIndex = variants.firstIndex(of: selectedVariant) {
            let selected = variants.remove(at: selectedIndex)
            variants.insert(selected, at: 0)
        }
        return variants
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(orderedVariants, id: \.self) { variant in
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