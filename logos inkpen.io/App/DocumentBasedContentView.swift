//
//  DocumentBasedContentView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import SwiftUI

// MARK: - DocumentBasedContentView (integrates DocumentGroup with MainView)
struct DocumentBasedContentView: View {
    @Binding var inkpenDocument: InkpenDocument
    let fileURL: URL?
    
    var body: some View {
        DocumentBasedMainView(document: inkpenDocument.document, fileURL: fileURL)
    }
}
