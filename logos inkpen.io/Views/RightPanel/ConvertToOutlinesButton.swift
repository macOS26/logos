//
//  ConvertToOutlinesButton.swift
//  logos inkpen.io
//
//  Created by Claude on 2025/01/15.
//

import SwiftUI

struct ConvertToOutlinesButton: View {
    @ObservedObject var document: VectorDocument
    let selectedText: VectorText?

    var body: some View {
        VStack {
            Divider()

            Button("Convert to Outlines") {
                convertSelectedTextToOutlines()
            }
            .buttonStyle(ProfessionalSecondaryButtonStyle())
            .frame(maxWidth: .infinity)
            .help("Convert text to vector paths (⌘⇧O)")
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(selectedText == nil)  // Disable when no text selected, but always visible
        }
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
