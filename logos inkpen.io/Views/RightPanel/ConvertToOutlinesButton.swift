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
            if selectedText != nil {
                Divider()
                
                HStack {
                    Button("Convert to Outlines") {
                        convertSelectedTextToOutlines()
                    }
                    .buttonStyle(ProfessionalPrimaryButtonStyle())
                    .font(.caption)
                    .help("Convert text to vector paths (⌘⇧O)")
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    // Removed content check - if text is selected, allow conversion

                    Spacer()

                    Text("Creates vector paths")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
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
