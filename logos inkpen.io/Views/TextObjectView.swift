//
//  TextObjectView.swift
//  logos
//
//  Simple wrapper for the new EditableTextCanvas system
//

import SwiftUI

struct TextObjectView: View {
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let isEditing: Bool
    
    @StateObject private var textEditorViewModel = TextEditorViewModel()
    
    var body: some View {
        EditableTextCanvas(viewModel: textEditorViewModel)
            .onAppear {
                // Basic sync from VectorText to TextEditorViewModel
                textEditorViewModel.text = textObject.content
                
                // Set the text box frame to include the VectorText position
                textEditorViewModel.textBoxFrame = CGRect(
                    x: textObject.position.x,
                    y: textObject.position.y,
                    width: max(textObject.bounds.width, 200),
                    height: max(textObject.bounds.height, 50)
                )
                
                textEditorViewModel.fontSize = textObject.typography.fontSize
                textEditorViewModel.textColor = textObject.typography.fillColor.color
                
                // Set font if available
                if let font = NSFont(name: textObject.typography.fontFamily, size: textObject.typography.fontSize) {
                    textEditorViewModel.selectedFont = font
                }
                
                // Set text alignment
                textEditorViewModel.textAlignment = convertToNSTextAlignment(textObject.typography.alignment)
                
                // Set line spacing
                textEditorViewModel.lineSpacing = textObject.typography.lineHeight - textObject.typography.fontSize
            }
    }
    
    private func convertToNSTextAlignment(_ textAlignment: TextAlignment) -> NSTextAlignment {
        switch textAlignment {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        case .justified:
            return .justified
        }
    }
}

 
