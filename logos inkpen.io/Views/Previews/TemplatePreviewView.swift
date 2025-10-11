
import SwiftUI

struct TemplatePreviewView: View {
    let template: TemplateManager.TemplateType

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .border(Color.gray.opacity(0.5), width: 1)

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
