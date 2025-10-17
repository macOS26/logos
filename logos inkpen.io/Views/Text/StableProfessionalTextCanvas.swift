import SwiftUI
import Combine

struct StableProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    let textObjectID: UUID
    @StateObject private var viewModel: ProfessionalTextViewModel

    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode

    init(document: VectorDocument, textObjectID: UUID, dragPreviewDelta: CGPoint = .zero, dragPreviewTrigger: Bool = false, viewMode: ViewMode = .color) {
        self.document = document
        self.textObjectID = textObjectID
        self.dragPreviewDelta = dragPreviewDelta
        self.dragPreviewTrigger = dragPreviewTrigger
        self.viewMode = viewMode

        let actualText = document.findText(by: textObjectID) ?? VectorText(content: "", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
        self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: actualText, document: document))
    }

    var body: some View {
        ProfessionalTextCanvas(
            document: document,
            viewModel: viewModel,
            textObjectID: textObjectID,
            dragPreviewDelta: dragPreviewDelta,
            dragPreviewTrigger: dragPreviewTrigger,
            viewMode: viewMode
        )
            .onAppear {
                updateViewModelFromDocument()
            }
            .onReceive(document.objectWillChange) { _ in
                if let currentTextObject = document.findText(by: textObjectID) {
                    viewModel.syncFromDocument(currentTextObject)
                }
            }
            .onChange(of: dragPreviewTrigger) { _, _ in
                if let currentTextObject = document.findText(by: textObjectID) {
                    viewModel.syncFromDocument(currentTextObject)
                }
            }

    }

    private func updateViewModelFromDocument() {
        if let currentTextObject = document.findText(by: textObjectID) {
            if viewModel.textObject.id != textObjectID {
                viewModel.textObject = currentTextObject
                viewModel.text = currentTextObject.content
                viewModel.fontSize = CGFloat(currentTextObject.typography.fontSize)
                viewModel.selectedFont = currentTextObject.typography.nsFont
                viewModel.textAlignment = currentTextObject.typography.alignment.nsTextAlignment

                let width = currentTextObject.areaSize?.width ?? (currentTextObject.bounds.width > 1 ? currentTextObject.bounds.width : 200.0)
                let height = currentTextObject.areaSize?.height ?? (currentTextObject.bounds.height > 1 ? currentTextObject.bounds.height : 50.0)

                viewModel.textBoxFrame = CGRect(
                    x: currentTextObject.position.x,
                    y: currentTextObject.position.y,
                    width: width,
                    height: height
                )
            } else {
                viewModel.syncFromDocument(currentTextObject)
            }
        }
    }

    private func getDocumentMode() -> String {
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
