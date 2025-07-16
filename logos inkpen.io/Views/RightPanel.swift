//
//  RightPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct RightPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var selectedTab: PanelTab = .layers
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            PanelTabBar(selectedTab: $selectedTab)
            
            // Content
            Group {
                switch selectedTab {
                case .layers:
                    LayersPanel(document: document)
                case .properties:
                    StrokeFillPanel(document: document)
                case .color:
                    ColorPanel(document: document)
                case .pathOps:
                    PathOperationsPanel(document: document)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .leading
        )
        .onAppear {
            // PROFESSIONAL PANEL SWITCHING (Adobe Illustrator Standards)
            NotificationCenter.default.addObserver(forName: .switchToPanel, object: nil, queue: .main) { notification in
                if let panelTab = notification.object as? PanelTab {
                    selectedTab = panelTab
                    print("🎨 Menu: Switched to panel: \(panelTab.rawValue)")
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
}













// PropertiesPanel removed - using StrokeFillPanel instead

// Old property structures removed - using StrokeFillPanel instead






















// MARK: - Professional Color Picker Modal

struct ColorPickerModal: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    let title: String
    let onColorSelected: (VectorColor) -> Void
    
    var body: some View {
        NavigationView {
            ColorPanel(document: document, onColorSelected: onColorSelected)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
        .frame(width: 300, height: 500)
    }
}

// Preview
struct RightPanel_Previews: PreviewProvider {
    static var previews: some View {
        RightPanel(document: VectorDocument())
            .frame(height: 600)
    }
}
