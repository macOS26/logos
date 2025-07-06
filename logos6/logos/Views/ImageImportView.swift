//
//  ImageImportView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// Simplified Image Import View for macOS compatibility
struct ImageImportView: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Image Import")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Image import functionality coming soon...")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}

// Preview
struct ImageImportView_Previews: PreviewProvider {
    static var previews: some View {
        ImageImportView(document: VectorDocument())
    }
}