//
//  BlankTemplatePreview.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

struct BlankTemplatePreview: View {
    var body: some View {
        VStack {
            Image(systemName: "doc")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            Text("Blank Document")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
