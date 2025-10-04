//
//  StableProfessionalTextCanvas.swift
//  logos inkpen.io
//
//  Lightweight text rendering - only creates view model when editing
//

import SwiftUI

// MARK: - Lightweight Text Canvas (No View Model Unless Editing)
struct StableProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    let textObjectID: UUID
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    var body: some View {
        if let textObject = document.allTextObjects.first(where: { $0.id == textObjectID }) {
            // Check if this text is being edited
            if textObject.isEditing {
                // EDITING MODE: Create full view model and editing canvas
                EditingTextCanvas(
                    document: document,
                    textObjectID: textObjectID,
                    dragPreviewDelta: dragPreviewDelta,
                    dragPreviewTrigger: dragPreviewTrigger
                )
            } else {
                // NON-EDITING MODE: Simple lightweight text display (no view model)
                LightweightTextDisplay(
                    textObject: textObject,
                    document: document,
                    dragPreviewDelta: dragPreviewDelta
                )
            }
        }
    }
}

// MARK: - Lightweight Text Display (For Non-Editing Text)
struct LightweightTextDisplay: View {
    let textObject: VectorText
    @ObservedObject var document: VectorDocument
    let dragPreviewDelta: CGPoint

    private var isSelected: Bool {
        document.selectedTextIDs.contains(textObject.id)
    }

    private var boxColor: Color {
        if isSelected {
            return Color.green.opacity(0.3)  // GREEN mode
        } else {
            return Color.gray.opacity(0.2)   // GRAY mode
        }
    }

    var body: some View {
        ZStack {
            // Text box border (gray or green)
            Rectangle()
                .stroke(isSelected ? Color.green : Color.gray, lineWidth: 1)
                .frame(width: textObject.bounds.width, height: textObject.bounds.height)
                .background(boxColor)

            // Text content
            Text(textObject.content)
                .font(Font(textObject.typography.nsFont))
                .foregroundColor(Color(nsColor: NSColor(textObject.typography.fillColor.color)))
                .frame(width: textObject.bounds.width, height: textObject.bounds.height, alignment: .topLeading)
        }
        .position(
            x: textObject.position.x + textObject.bounds.width / 2,
            y: textObject.position.y + textObject.bounds.height / 2
        )
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        // Apply drag preview ONLY if selected
        .offset(
            x: isSelected ? dragPreviewDelta.x * document.zoomLevel : 0,
            y: isSelected ? dragPreviewDelta.y * document.zoomLevel : 0
        )
        .contentShape(Rectangle())  // Make entire frame tappable
        .onTapGesture {
            handleTap()
        }
    }

    private func handleTap() {
        // Select this text object
        if !isSelected {
            document.selectedTextIDs = [textObject.id]
            document.selectedShapeIDs.removeAll()
            Log.info("🎯 LIGHTWEIGHT TEXT: Selected '\(textObject.content.prefix(20))'", category: .general)
        }
    }
}

// MARK: - Editing Text Canvas (With View Model)
struct EditingTextCanvas: View {
    @ObservedObject var document: VectorDocument
    let textObjectID: UUID
    @StateObject private var viewModel: ProfessionalTextViewModel
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    init(document: VectorDocument, textObjectID: UUID, dragPreviewDelta: CGPoint, dragPreviewTrigger: Bool) {
        self.document = document
        self.textObjectID = textObjectID
        self.dragPreviewDelta = dragPreviewDelta
        self.dragPreviewTrigger = dragPreviewTrigger

        // Create view model ONLY for editing text
        if let textObject = document.allTextObjects.first(where: { $0.id == textObjectID }) {
            Log.info("📝 EDITING: Creating view model for '\(textObject.content.prefix(20))'", category: .general)
            self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: textObject, document: document))
        } else {
            let fallbackText = VectorText(content: "Text", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
            self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: fallbackText, document: document))
        }
    }

    var body: some View {
        ProfessionalTextCanvas(
            document: document,
            viewModel: viewModel,
            textObjectID: textObjectID,
            dragPreviewDelta: dragPreviewDelta,
            dragPreviewTrigger: dragPreviewTrigger
        )
    }
}
