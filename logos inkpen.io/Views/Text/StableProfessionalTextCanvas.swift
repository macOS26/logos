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
        // Access unified objects directly instead of allTextObjects
        if let unifiedObj = document.unifiedObjects.first(where: { $0.id == textObjectID }),
           case .shape(let shape) = unifiedObj.objectType,
           shape.isTextObject,
           var textObject = VectorText.from(shape) {
            textObject.layerIndex = unifiedObj.layerIndex
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
                // Check if our text object has changed
                if let unifiedObj = document.unifiedObjects.first(where: { $0.id == textObjectID }),
                   case .shape(let shape) = unifiedObj.objectType,
                   shape.isTextObject,
                   var currentTextObject = VectorText.from(shape) {
                    currentTextObject.layerIndex = unifiedObj.layerIndex
                    // Always sync when document changes - the unified system is the source of truth
                    viewModel.syncFromDocument(currentTextObject)
                }
            }
            // Additional fix: Use id to force view refresh when text content changes
            .id("\(textObjectID)-\(getDocumentMode())")

    }

    private func updateViewModelFromDocument() {
        // Access unified system directly
        if let unifiedObj = document.unifiedObjects.first(where: { $0.id == textObjectID }),
           case .shape(let shape) = unifiedObj.objectType,
           shape.isTextObject,
           var currentTextObject = VectorText.from(shape) {
            currentTextObject.layerIndex = unifiedObj.layerIndex
            viewModel.syncFromDocument(currentTextObject)
            Log.fileOperation("✅ TEXT CANVAS: Found text object \(textObjectID.uuidString.prefix(8)) content: '\(currentTextObject.content)'", level: .info)
        } else {
            // FALLBACK: If text object missing from unified objects, log issue with debugging info
            Log.fileOperation("⚠️ TEXT CANVAS: Text object \(textObjectID.uuidString.prefix(8)) not found in unified objects", level: .info)
            let textShapeIDs = document.unifiedObjects.compactMap { obj -> String? in
                if case .shape(let shape) = obj.objectType, shape.isTextObject {
                    return String(obj.id.uuidString.prefix(8))
                }
                return nil
            }
            Log.fileOperation("🔍 DEBUG: Available text object IDs: \(textShapeIDs)", level: .info)
            Log.fileOperation("🔍 DEBUG: Total text objects: \(textShapeIDs.count)", level: .info)
        }
    }

    private func getDocumentMode() -> String {
        if let unifiedObj = document.unifiedObjects.first(where: { $0.id == textObjectID }),
           case .shape(let shape) = unifiedObj.objectType,
           shape.isTextObject {
            // PROFESSIONAL UX: Stable view while font tool is active
            // Create compact typography hash to avoid super long strings

            if document.currentTool == .font {
                // While font tool is active, exclude content to prevent view recreation during typing
                return "font-tool"
            } else {
                // When other tools are active, include content for proper updates
                let editing = (shape.isEditing ?? false) ? "editing" : "not-editing"
                return "\(shape.textContent ?? "")-\(editing)"
            }
        }
        return "text-missing"
    }
}
