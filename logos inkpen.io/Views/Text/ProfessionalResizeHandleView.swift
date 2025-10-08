//
//  ProfessionalResizeHandleView.swift
//  logos inkpen.io
//
//  Resize handle view for text boxes
//

import SwiftUI

// MARK: - Professional Resize Handle (Based on Working ResizeHandleView)
struct ProfessionalResizeHandleView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let zoomLevel: CGFloat
    let onResizeChanged: (DragGesture.Value) -> Void
    let onResizeEnded: () -> Void
    let onResizeStarted: () -> Void // NEW: Track when resize starts

    @State private var hasResizeStarted = false  // Track if resize has been initiated

    var body: some View {
        Circle()
            .fill(Color.blue)
            .stroke(Color.white, lineWidth: 1.0 / zoomLevel) // Compensate for parent scaleEffect
            .frame(width: 10 / zoomLevel, height: 10 / zoomLevel) // Compensate for parent scaleEffect (same size as transform box handles)
            .position(
                x: viewModel.textBoxFrame.maxX + dragOffset.width + resizeOffset.width,
                y: viewModel.textBoxFrame.maxY + dragOffset.height + resizeOffset.height
            )
            .gesture(
                DragGesture(minimumDistance: 1)  // IMPROVED: Lower threshold for immediate response
                    .onChanged { value in
                        // IMPROVED: Call onResizeStarted only once when drag first begins
                        if !hasResizeStarted {
                            hasResizeStarted = true
                            onResizeStarted()
                        }
                        // RESIZE HANDLE DRAG: \(value.translation)
                        onResizeChanged(value)
                    }
                    .onEnded { _ in
                        hasResizeStarted = false  // Reset for next resize operation
                        onResizeEnded()
                    }
            )
            .onAppear {
            }
    }
}
