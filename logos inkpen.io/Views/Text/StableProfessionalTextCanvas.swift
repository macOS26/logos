//
//  StableProfessionalTextCanvas.swift
//  logos inkpen.io
//
//  Professional text editing using the proven working NewTextBoxFontTool approach
//  Stable wrapper that prevents ViewModel recreation
//

import SwiftUI
import Combine

// MARK: - Stable Text Canvas Wrapper (Prevents ViewModel Recreation)
struct StableProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    let textObjectID: UUID
    @StateObject private var viewModel: ProfessionalTextViewModel

    // NEW: Drag preview parameters for live preview during dragging
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    init(document: VectorDocument, textObjectID: UUID, dragPreviewDelta: CGPoint = .zero, dragPreviewTrigger: Bool = false) {
        self.document = document
        self.textObjectID = textObjectID
        self.dragPreviewDelta = dragPreviewDelta
        self.dragPreviewTrigger = dragPreviewTrigger

        // Create view model ONCE and reuse it
        // Use allTextObjects computed property instead of textObjects array
        if let textObject = document.allTextObjects.first(where: { $0.id == textObjectID }) {
            Log.info("📝 StableProfessionalTextCanvas: Creating view model for text '\(textObject.content.prefix(20))' at position \(textObject.position)", category: .general)
            self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: textObject, document: document))
        } else {
            // MIGRATION FIX: Create fallback text with proper content
            Log.error("⚠️ StableProfessionalTextCanvas: Text object \(textObjectID) not found! Creating fallback", category: .error)
            let fallbackText = VectorText(content: "Text", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
            self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: fallbackText, document: document))
        }
    }

    var body: some View {
        // Update view model when text object changes (without recreating it)
        ProfessionalTextCanvas(
            document: document,
            viewModel: viewModel,
            textObjectID: textObjectID,
            dragPreviewDelta: dragPreviewDelta,
            dragPreviewTrigger: dragPreviewTrigger
        )
            .onAppear {
                updateViewModelFromDocument()
            }
            // CRITICAL FIX: Monitor document changes directly via objectWillChange
            // This ensures we catch ALL changes including nested typography updates
            .onReceive(document.objectWillChange) { _ in
                // PERFORMANCE: Use UUID lookup instead of looping
                if let currentTextObject = document.findText(by: textObjectID) {
                    viewModel.syncFromDocument(currentTextObject)
                }
            }
            // Additional fix: Use id to force view refresh when text content changes
            .id("\(textObjectID)-\(getDocumentMode())")

    }

    private func updateViewModelFromDocument() {
        // PERFORMANCE: Use UUID lookup instead of looping
        if let currentTextObject = document.findText(by: textObjectID) {
            viewModel.syncFromDocument(currentTextObject)
            Log.fileOperation("✅ TEXT CANVAS: Found text object \(textObjectID.uuidString.prefix(8)) content: '\(currentTextObject.content)'", level: .info)
        } else {
            Log.fileOperation("⚠️ TEXT CANVAS: Text object \(textObjectID.uuidString.prefix(8)) not found", level: .info)
        }
    }

    private func getDocumentMode() -> String {
        // PERFORMANCE: Use UUID lookup instead of looping
        if let currentTextObject = document.findText(by: textObjectID) {
            if document.currentTool == .font {
                return "font-tool"
            } else {
                return "\(currentTextObject.content)-\(currentTextObject.isEditing)"
            }
        }
        return "text-missing"
    }
}
