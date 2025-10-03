//
//  ProfessionalTextViews.swift
//  logos inkpen.io
//
//  Text canvas view components - Box, Display and Content views
//

import SwiftUI

// MARK: - Professional Text Box View (Based on Working TextBoxView)
struct ProfessionalTextBoxView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    let isResizeHandleActive: Bool  // NEW: Track resize handle state
    let onTextBoxSelect: (CGPoint) -> Void
    let zoomLevel: CGFloat
    // REMOVED: onDragChanged and onDragEnded - arrow tool handles all dragging

    private func getBorderColor() -> Color {
        switch textBoxState {
        case .gray: return Color.gray
        case .green: return Color.green
        case .blue: return Color.blue
        }
    }

    var body: some View {
        ZStack {
            // Main text box rectangle with clear background
            Rectangle()
                .fill(Color.clear) // Clear background - arrow tool handles hit detection
                .stroke(getBorderColor(), lineWidth: 1.0 / max(zoomLevel, 0.0001)) // Always ~1px on screen
                .frame(
                    width: viewModel.textBoxFrame.width + resizeOffset.width,
                    height: viewModel.textBoxFrame.height + resizeOffset.height
                )
                .position(
                    x: viewModel.textBoxFrame.minX + dragOffset.width + (viewModel.textBoxFrame.width + resizeOffset.width) / 2,
                    y: viewModel.textBoxFrame.minY + dragOffset.height + (viewModel.textBoxFrame.height + resizeOffset.height) / 2
                )
                .onTapGesture(count: 1) { location in
                    onTextBoxSelect(location)
                }
                .onTapGesture(count: 2) { location in
                    // Double-click: call the proper interaction handler
                    Log.info("🔧 DOUBLE-CLICK DETECTED on text box", category: .general)
                    viewModel.handleTextBoxInteraction(textID: viewModel.textObject.id, isDoubleClick: true)
                }
                // REMOVED: Explicit drag gesture - let arrow tool handle all dragging naturally
                // FIXED: Allow hit testing in all modes so arrow tool can select and move text objects
                .allowsHitTesting(true)

            // REMOVED: Red corner circles were jumping around and awful
        }
    }
}

// MARK: - Professional Text Display (Based on Working TextDisplayView)
struct ProfessionalTextDisplayView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let textBoxState: ProfessionalTextCanvas.TextBoxState

    var body: some View {
        Group {
            ProfessionalTextContentView(
                viewModel: viewModel,
                textBoxState: textBoxState
            )
            .position(
                x: viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2,
                y: viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2
            )
        }
    }
}

// MARK: - Professional Text Content (Based on Working TextContentView)
struct ProfessionalTextContentView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let textBoxState: ProfessionalTextCanvas.TextBoxState

    var body: some View {
        // CRITICAL FIX: Pass text box state to control NSTextView editability
        // This prevents i-beam cursor from appearing when not in edit mode
        let shouldAllowHitTesting = textBoxState == .blue  // Only allow interaction in blue mode
        ProfessionalUniversalTextView(viewModel: viewModel, textBoxState: textBoxState)
            .allowsHitTesting(shouldAllowHitTesting) // Additional safety: control interaction here too
            .frame(
                width: viewModel.textBoxFrame.width,     // FIXED WIDTH - NEVER CHANGES
                height: viewModel.textBoxFrame.height,   // CURRENT HEIGHT
                alignment: .topLeading
            )
            .clipped()  // CRITICAL: Clip any overflow to prevent horizontal expansion
            .onAppear {
                // Text view appeared - no need for verbose logging
            }
    }
}