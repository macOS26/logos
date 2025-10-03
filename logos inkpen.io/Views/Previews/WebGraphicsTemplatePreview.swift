//
//  WebGraphicsTemplatePreview.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

struct WebGraphicsTemplatePreview: View {
    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.ui.lightErrorBackground2)
                .frame(height: 30)
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.ui.lightErrorBackground2)
                    .frame(width: 100)
                
                Rectangle()
                    .fill(Color.ui.lightErrorBackground2)
                    .frame(width: 120)
                
                Rectangle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 80)
            }
            .frame(height: 60)
            
            Rectangle()
                .fill(Color.purple.opacity(0.1))
                .frame(height: 80)
        }
        .padding()
        .overlay(
            Rectangle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                .padding(4)
        )
    }
}
