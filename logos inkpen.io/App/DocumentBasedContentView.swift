
import SwiftUI

struct DocumentBasedContentView: View {
    @Binding var inkpenDocument: InkpenDocument
    let fileURL: URL?

    var body: some View {
        DocumentBasedMainView(document: inkpenDocument.document, fileURL: fileURL)
    }
}
