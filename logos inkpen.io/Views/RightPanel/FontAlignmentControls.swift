
import SwiftUI
import Combine

struct FontAlignmentControls: View {
    @ObservedObject var document: VectorDocument
    let selectedText: VectorText?
    let editingText: VectorText?

    private var currentTextAlignment: NSTextAlignment {
        if let selectedText = selectedText {
            return selectedText.typography.alignment.nsTextAlignment
        } else if let editingText = editingText {
            return editingText.typography.alignment.nsTextAlignment
        } else {
            return document.fontManager.selectedTextAlignment.nsTextAlignment
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alignment")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Button {
                    updateAlignment(.left)
                } label: {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 14))
                        .foregroundColor(currentTextAlignment == .left ? .white : .primary)
                        .frame(width: 36, height: 28)
                        .background(currentTextAlignment == .left ? Color.blue : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .onTapGesture {
                    updateAlignment(.left)
                }
                .help("Align Left")

                Button {
                    updateAlignment(.center)
                } label: {
                    Image(systemName: "text.aligncenter")
                        .font(.system(size: 14))
                        .foregroundColor(currentTextAlignment == .center ? .white : .primary)
                        .frame(width: 36, height: 28)
                        .background(currentTextAlignment == .center ? Color.blue : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .onTapGesture {
                    updateAlignment(.center)
                }
                .help("Align Center")

                Button {
                    updateAlignment(.right)
                } label: {
                    Image(systemName: "text.alignright")
                        .font(.system(size: 14))
                        .foregroundColor(currentTextAlignment == .right ? .white : .primary)
                        .frame(width: 36, height: 28)
                        .background(currentTextAlignment == .right ? Color.blue : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .onTapGesture {
                    updateAlignment(.right)
                }
                .help("Align Right")

                Button {
                    updateAlignment(.justified)
                } label: {
                    Image(systemName: "text.justify")
                        .font(.system(size: 14))
                        .foregroundColor(currentTextAlignment == .justified ? .white : .primary)
                        .frame(width: 36, height: 28)
                        .background(currentTextAlignment == .justified ? Color.blue : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .onTapGesture {
                    updateAlignment(.justified)
                }
                .help("Justify")

                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private func updateAlignment(_ alignment: TextAlignment) {
        document.fontManager.selectedTextAlignment = alignment

        if let textID = document.selectedTextIDs.first,
           let freshText = document.findText(by: textID) {
            var updatedTypography = freshText.typography
            updatedTypography.alignment = alignment
            document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
        }

        document.objectWillChange.send()
    }
}
