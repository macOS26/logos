//
//  ColorPickerModal.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Professional Color Picker Modal

struct ColorPickerModal: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    let title: String
    let onColorSelected: (VectorColor) -> Void
    
    var body: some View {
        NavigationView {
            ColorPanel(document: document, onColorSelected: onColorSelected)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
        }
        .frame(width: 300, height: 500)
    }
} 