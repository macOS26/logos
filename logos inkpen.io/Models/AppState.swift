import SwiftUI

@Observable
class AppState {
    var selectedPanelTab: PanelTab = .layers
    
    // MARK: - Panel Actions
    func showLayersPanel() {
        selectedPanelTab = .layers
        print("🎨 AppState: Switched to layers panel")
    }
    
    func showColorPanel() {
        selectedPanelTab = .color
        print("🎨 AppState: Switched to color panel")
    }
    
    func showStrokeFillPanel() {
        selectedPanelTab = .properties
        print("🎨 AppState: Switched to stroke/fill panel")
    }
    
    func showPathOpsPanel() {
        selectedPanelTab = .pathOps
        print("🎨 AppState: Switched to path ops panel")
    }
    
    func showFontPanel() {
        selectedPanelTab = .font
        print("🎨 AppState: Switched to font panel")
    }
    
    // MARK: - Development Actions
    var showingCoreGraphicsTest = false
    
    func showCoreGraphicsTest() {
        showingCoreGraphicsTest = true
        print("🧪 AppState: Showing CoreGraphics test")
    }
    
    func runPathOperationsBenchmark() {
        print("⚡ AppState: Running path operations benchmark")
        // TODO: Move benchmark logic to a utility class
        // For now, just print a message
        print("🚀 RUNNING PATH OPERATIONS BENCHMARK")
        print("📊 Benchmark functionality to be implemented in utility class")
        print("✅ BENCHMARK PLACEHOLDER COMPLETE")
    }
} 