//
//  RightPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct RightPanel: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            PanelTabBar(selectedTab: Binding(
                get: { appState.selectedPanelTab },
                set: { appState.selectedPanelTab = $0 }
            ))
            
            // Content
            Group {
                switch appState.selectedPanelTab {
                case .layers:
                    LayersPanel(document: document)
                case .properties:
                    StrokeFillPanel(document: document)
                case .color:
                    ColorPanel(document: document)
                case .pathOps:
                    PathOperationsPanel(document: document)
                case .font:
                    FontPanel(document: document)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .leading
        )

    }
}













// PropertiesPanel removed - using StrokeFillPanel instead

// Old property structures removed - using StrokeFillPanel instead
























// Preview
struct RightPanel_Previews: PreviewProvider {
    static var previews: some View {
        RightPanel(document: VectorDocument())
            .frame(height: 600)
    }
}
