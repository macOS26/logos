//
//  TemplateSelectionView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

/// Professional Template Selection View for New Document Creation
struct TemplateSelectionView: View {
    @Binding var isPresented: Bool
    let onTemplateSelected: (TemplateManager.TemplateType) -> Void
    
    @State private var selectedTemplate: TemplateManager.TemplateType = .blank
    @State private var showCustomTemplates: Bool = false
    
    private let templateManager = TemplateManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            contentSection
            actionButtonsSection
        }
        .padding(24)
        .frame(width: 800, height: 600)
        .onAppear {
            selectedTemplate = .blank
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Document")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Choose a template to get started")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                }
                
                Spacer()
            }
            
            Divider()
        }
    }
    
    private var contentSection: some View {
        HStack(spacing: 24) {
            templateListSection
            Divider()
            templatePreviewSection
        }
    }
    
    private var templateListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Professional Templates")
                .font(.headline)
                .foregroundColor(Color.ui.primaryText)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(templateManager.getAvailableTemplates(), id: \.self) { template in
                        TemplateRowView(
                            template: template,
                            isSelected: selectedTemplate == template,
                            onSelect: {
                                selectedTemplate = template
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 300)
    }
    
    private var templatePreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(Color.ui.primaryText)
            
            TemplatePreviewView(template: selectedTemplate)
                .frame(width: 400, height: 300)
                .background(Color.ui.lightGrayBackground)
                .cornerRadius(8)
            
            templateDetailsSection
        }
    }
    
    private var templateDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedTemplate.displayName)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(selectedTemplate.description)
                .font(.body)
                .foregroundColor(Color.ui.secondaryText)
            
            if let templateConfig = templateManager.getTemplate(selectedTemplate) {
                templateSpecificationsSection(templateConfig)
            }
        }
    }
    
    private func templateSpecificationsSection(_ templateConfig: TemplateManager.TemplateConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Specifications:")
                .font(.headline)
            
            specificationRow("Size:", "\(Int(templateConfig.settings.width)) × \(Int(templateConfig.settings.height)) \(templateConfig.settings.unit.rawValue)")
            specificationRow("DPI:", "\(Int(templateConfig.settings.resolution))")
            specificationRow("Layers:", "\(templateConfig.initialLayers.count)")
            specificationRow("Initial Objects:", "\(templateConfig.initialShapes.count)")
        }
        .padding()
        .background(Color.ui.veryLightGrayBackground)
        .cornerRadius(8)
    }
    
    private func specificationRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(Color.ui.secondaryText)
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            Button("Create Document") {
                onTemplateSelected(selectedTemplate)
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }
}

#Preview {
    TemplateSelectionView(
        isPresented: .constant(true),
        onTemplateSelected: { _ in }
    )
} 
