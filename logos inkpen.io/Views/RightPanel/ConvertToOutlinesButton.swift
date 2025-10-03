//
//  ConvertToOutlinesButton.swift
//  logos inkpen.io
//
//  Created by Claude on 2025/01/15.
//

import SwiftUI

// Custom button style for full-width button without horizontal padding
struct FullWidthSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ConvertToOutlinesButton: View {
    @ObservedObject var document: VectorDocument
    let selectedText: VectorText?

    var body: some View {
        Button("Convert to Outlines") {
            convertSelectedTextToOutlines()
        }
        .buttonStyle(FullWidthSecondaryButtonStyle())
        .help("Convert text to vector paths (⌘⇧O)")
        .keyboardShortcut("o", modifiers: [.command, .shift])
        .disabled(selectedText == nil)  // Disable when no text selected, but always visible
    }
    
    private func convertSelectedTextToOutlines() {
        guard !document.selectedTextIDs.isEmpty else {
            Log.error("❌ CONVERT TO OUTLINES: No text selected", category: .error)
            return
        }

        // Check if selected layer is locked
        if let layerIndex = document.selectedLayerIndex,
           layerIndex >= 0 && layerIndex < document.layers.count {
            let layer = document.layers[layerIndex]
            if layer.isLocked {
                Log.error("❌ CONVERT TO OUTLINES: Layer '\(layer.name)' is locked", category: .error)
                return
            }
        }

        document.convertSelectedTextToOutlines()
    }
}
