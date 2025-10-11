
import SwiftUI

struct ToolSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 4) {
            content
        }
    }
}
