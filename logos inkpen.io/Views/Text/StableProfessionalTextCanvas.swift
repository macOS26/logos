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

        // PERF: Defer view model creation until onAppear to prevent blocking during document load
        // This allows the window to appear immediately even with 100+ text boxes
        let fallbackText = VectorText(content: "", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
        self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: fallbackText, document: document))
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
            // PERF: Update position when drag preview changes
            .onChange(of: dragPreviewTrigger) { _, _ in
                if let currentTextObject = document.findText(by: textObjectID) {
                    viewModel.syncFromDocument(currentTextObject)
                }
            }
            // PERF: Removed .id() modifier - was causing view to recreate on every drag
            // The view model's @StateObject ensures stability across updates

    }

    private func updateViewModelFromDocument() {
        // PERF: Initialize view model with actual text object on first appearance
        // This defers expensive setup until the view is actually rendered
        if let currentTextObject = document.findText(by: textObjectID) {
            // Check if view model has the wrong ID (initial dummy object)
            if viewModel.textObject.id != textObjectID {
                // First time only - replace dummy with real text object
                viewModel.textObject = currentTextObject
                viewModel.text = currentTextObject.content
                viewModel.fontSize = CGFloat(currentTextObject.typography.fontSize)
                viewModel.selectedFont = currentTextObject.typography.nsFont
                viewModel.textAlignment = currentTextObject.typography.alignment.nsTextAlignment

                // Use bounds from file if available
                let width = currentTextObject.areaSize?.width ?? (currentTextObject.bounds.width > 1 ? currentTextObject.bounds.width : 200.0)
                let height = currentTextObject.areaSize?.height ?? (currentTextObject.bounds.height > 1 ? currentTextObject.bounds.height : 50.0)

                viewModel.textBoxFrame = CGRect(
                    x: currentTextObject.position.x,
                    y: currentTextObject.position.y,
                    width: width,
                    height: height
                )
            } else {
                // Already initialized - just sync position/properties (no re-init)
                viewModel.syncFromDocument(currentTextObject)
            }
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
