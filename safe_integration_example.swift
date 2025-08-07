import SwiftUI

// EXAMPLE: How to safely integrate Metal pseudo-object into existing components
// This shows how to do it WITHOUT breaking anything

// ============================================================================
// OPTION 1: Add Metal as an OPTIONAL overlay (safest approach)
// ============================================================================

extension DrawingCanvas {
    
    /// Drop-in replacement for canvasMainContent that adds optional Metal acceleration
    /// To use: Replace `canvasMainContent(geometry: geometry)` with `safeMetalCanvasContent(geometry: geometry)`
    @ViewBuilder
    internal func safeMetalCanvasContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // 🔒 EXISTING CODE (unchanged - zero risk of breaking)
            canvasBaseContent(geometry: geometry)
            pressureSensitiveOverlay(geometry: geometry)
            
            // ✨ NEW: Optional Metal acceleration layer
            // This only activates if you want it, and can be turned off instantly
            if false { // Change to `true` when you want to test Metal acceleration
                SafeMetalView { cgContext, size in
                    // Only render non-critical enhancements
                    renderOptionalMetalEffects(cgContext: cgContext, size: size, geometry: geometry)
                }
                .allowsHitTesting(false) // Doesn't interfere with existing interactions
                .opacity(0.99) // Slightly transparent so it doesn't block anything
            }
        }
        // 🔒 ALL EXISTING MODIFIERS (unchanged)
        .onAppear {
            setupCanvas(geometry: geometry)
            setupKeyEventMonitoring()
            setupToolKeyboardShortcuts()
            previousTool = document.currentTool
        }
        // ... rest of your existing code exactly as-is
    }
    
    private func renderOptionalMetalEffects(cgContext: CGContext, size: CGSize, geometry: GeometryProxy) {
        // Only render things that enhance UX but aren't critical
        // Examples: subtle animations, grid overlays, selection hints
        
        // Example: Enhanced grid with subtle glow effect
        if document.snapToGrid {
            cgContext.setStrokeColor(CGColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.3))
            cgContext.setLineWidth(0.5)
            // ... grid rendering code
        }
    }
}

// ============================================================================
// OPTION 2: Enhance specific UI components (very safe)
// ============================================================================

/// Metal-enhanced version of LayerView (can be swapped in/out easily)
struct SafeMetalLayerView: View {
    let layer: VectorLayer
    let zoomLevel: Double
    let canvasOffset: CGPoint
    // ... other parameters same as LayerView
    
    @State private var useMetalAcceleration = false // Toggle for testing
    
    var body: some View {
        if useMetalAcceleration {
            // Metal-accelerated rendering
            SafeMetalView { cgContext, size in
                renderLayerWithMetal(cgContext: cgContext, size: size)
            }
        } else {
            // 🔒 FALLBACK: Use existing LayerView (zero risk)
            LayerView(
                layer: layer,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset
                // ... other parameters
            )
        }
    }
    
    private func renderLayerWithMetal(cgContext: CGContext, size: CGSize) {
        // Custom Metal rendering for this layer
        // If anything goes wrong, just set useMetalAcceleration = false
    }
}

// ============================================================================
// OPTION 3: Progressive enhancement pattern (safest for testing)
// ============================================================================

struct ProgressiveMetalCanvas: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) var appState
    
    // Feature flags for safe testing
    @State private var metalGridEnabled = false
    @State private var metalOverlaysEnabled = false
    @State private var metalAnimationsEnabled = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 🔒 CORE FUNCTIONALITY (never changes)
                coreCanvasContent(geometry: geometry)
                
                // ✨ PROGRESSIVE ENHANCEMENTS (can be toggled individually)
                if metalGridEnabled {
                    metalEnhancedGrid(geometry: geometry)
                }
                
                if metalOverlaysEnabled {
                    metalEnhancedOverlays(geometry: geometry)
                }
                
                if metalAnimationsEnabled {
                    metalEnhancedAnimations(geometry: geometry)
                }
            }
        }
        .toolbar {
            // Debug controls (remove in production)
            ToolbarItem(placement: .automatic) {
                Menu("Metal Debug") {
                    Toggle("Metal Grid", isOn: $metalGridEnabled)
                    Toggle("Metal Overlays", isOn: $metalOverlaysEnabled)
                    Toggle("Metal Animations", isOn: $metalAnimationsEnabled)
                }
            }
        }
    }
    
    @ViewBuilder
    private func coreCanvasContent(geometry: GeometryProxy) -> some View {
        // Your existing DrawingCanvas code goes here
        // This never changes, so zero risk of breaking
        Text("Your existing canvas content here")
    }
    
    @ViewBuilder
    private func metalEnhancedGrid(geometry: GeometryProxy) -> some View {
        SafeMetalView { cgContext, size in
            // Enhanced grid rendering
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private func metalEnhancedOverlays(geometry: GeometryProxy) -> some View {
        SafeMetalView { cgContext, size in
            // Enhanced overlays
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private func metalEnhancedAnimations(geometry: GeometryProxy) -> some View {
        SafeMetalView { cgContext, size in
            // Enhanced animations
        }
        .allowsHitTesting(false)
    }
}

// ============================================================================
// USAGE EXAMPLES (how to integrate without breaking anything)
// ============================================================================

/*

// IN YOUR EXISTING CODE:

// Before (your current working code):
var body: some View {
    GeometryReader { geometry in
        canvasMainContent(geometry: geometry)  // ← Your existing code
    }
}

// After (safe Metal integration):
var body: some View {
    GeometryReader { geometry in
        safeMetalCanvasContent(geometry: geometry)  // ← Drop-in replacement
    }
}

// If anything breaks, just change it back to:
// canvasMainContent(geometry: geometry)

*/

// ============================================================================
// TESTING STRATEGY (how to verify it's working safely)
// ============================================================================

/*

1. GRADUAL TESTING:
   - Start with `useMetalAcceleration = false` (everything works as before)
   - Change to `true` for one component at a time
   - Test each component thoroughly before moving to the next

2. EASY ROLLBACK:
   - All Metal features are behind toggles
   - Can be disabled instantly if issues arise
   - Original code remains untouched

3. NON-BREAKING INTEGRATION:
   - Metal layers don't interfere with existing gestures
   - Use `.allowsHitTesting(false)` on Metal overlays
   - Keep original rendering as fallback

4. MONITORING:
   - Check console for Metal device status
   - Monitor performance improvements
   - Verify no regressions in existing functionality

*/
