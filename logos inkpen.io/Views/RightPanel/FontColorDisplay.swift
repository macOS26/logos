//
//  FontColorDisplay.swift
//  logos inkpen.io
//
//  Created by Claude on 2025/01/15.
//

import SwiftUI

struct FontColorDisplay: View {
    let selectedText: VectorText?
    
    var body: some View {
        if let selectedText = selectedText {
            VStack {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fill Color")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("Use Stroke/Fill panel to change")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        renderColorSwatchRightPanel(selectedText.typography.fillColor, width: 20, height: 20, cornerRadius: 0, borderWidth: 1)
                        Text("Fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}