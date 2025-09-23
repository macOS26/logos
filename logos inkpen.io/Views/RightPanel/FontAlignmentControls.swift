//
//  FontAlignmentControls.swift
//  logos inkpen.io
//
//  Created by Claude on 2025/01/15.
//

import SwiftUI

struct FontAlignmentControls: View {
    @ObservedObject var document: VectorDocument
    let selectedText: VectorText?
    let editingText: VectorText?
    
    private var currentTextAlignment: NSTextAlignment {
        if let selectedText = selectedText {
            return selectedText.typography.alignment.nsTextAlignment
        } else if let editingText = editingText {
            return editingText.typography.alignment.nsTextAlignment
        } else {
            return document.fontManager.selectedTextAlignment.nsTextAlignment
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alignment")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                // Left Align
                Button {
                    updateAlignment(.left)
                } label: {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 14))
                        .foregroundColor(currentTextAlignment == .left ? .white : .primary)
                        .frame(width: 36, height: 28)
                        .background(currentTextAlignment == .left ? Color.blue : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Align Left")
                
                // Center Align
                Button {
                    updateAlignment(.center)
                } label: {
                    Image(systemName: "text.aligncenter")
                        .font(.system(size: 14))
                        .foregroundColor(currentTextAlignment == .center ? .white : .primary)
                        .frame(width: 36, height: 28)
                        .background(currentTextAlignment == .center ? Color.blue : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Align Center")
                
                // Right Align
                Button {
                    updateAlignment(.right)
                } label: {
                    Image(systemName: "text.alignright")
                        .font(.system(size: 14))
                        .foregroundColor(currentTextAlignment == .right ? .white : .primary)
                        .frame(width: 36, height: 28)
                        .background(currentTextAlignment == .right ? Color.blue : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Align Right")
                
                // Justify
                Button {
                    updateAlignment(.justified)
                } label: {
                    Image(systemName: "text.justify")
                        .font(.system(size: 14))
                        .foregroundColor(currentTextAlignment == .justified ? .white : .primary)
                        .frame(width: 36, height: 28)
                        .background(currentTextAlignment == .justified ? Color.blue : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Justify")
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    private func updateAlignment(_ alignment: TextAlignment) {
        if let textID = document.selectedTextIDs.first,
           let freshText = document.allTextObjects.first(where: { $0.id == textID }) {
            var updatedTypography = freshText.typography
            updatedTypography.alignment = alignment
            document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
        } else {
            document.fontManager.selectedTextAlignment = alignment
        }
    }
}