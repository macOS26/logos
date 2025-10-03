//
//  TemplatePreviewView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

/// Template Preview Visualization
struct TemplatePreviewView: View {
    let template: TemplateManager.TemplateType
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.white)
                .border(Color.gray.opacity(0.5), width: 1)
            
            // Template-specific preview
            Group {
                switch template {
                case .blank:
                    BlankTemplatePreview()
                case .businessCard:
                    BusinessCardTemplatePreview()
                case .letterhead:
                    LetterheadTemplatePreview()
                case .poster:
                    PosterTemplatePreview()
                case .logo:
                    LogoTemplatePreview()
                case .architectural:
                    ArchitecturalTemplatePreview()
                case .engineering:
                    EngineeringTemplatePreview()
                case .webGraphics:
                    WebGraphicsTemplatePreview()
                }
            }
        }
        .clipped()
    }
}
