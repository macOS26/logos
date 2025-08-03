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

/// Individual Template Row
struct TemplateRowView: View {
    let template: TemplateManager.TemplateType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconName)
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(template.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.title3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

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

// MARK: - Individual Template Preview Components

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

struct BusinessCardTemplatePreview: View {
    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.ui.lightBlueBackground)
                .frame(height: 20)
            
            HStack {
                VStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 80, height: 4)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 60, height: 2)
                }
                Spacer()
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                .padding(8)
        )
    }
}

struct LetterheadTemplatePreview: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.ui.lightBlueBackground)
                .frame(height: 40)
            
            Rectangle()
                .fill(Color.white)
                .overlay(
                    VStack(spacing: 4) {
                        ForEach(0..<8, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                    }
                    .padding()
                )
        }
    }
}

struct PosterTemplatePreview: View {
    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.purple.opacity(0.2))
                .frame(height: 60)
            
            Rectangle()
                .fill(Color.orange.opacity(0.1))
                .frame(height: 120)
            
            Rectangle()
                .fill(Color.ui.lightSuccessBackground)
                .frame(height: 40)
        }
        .background(Color.white)
    }
}

struct LogoTemplatePreview: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                .frame(width: 100, height: 100)
            
            Text("LOGO")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
        }
    }
}

struct ArchitecturalTemplatePreview: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 80, height: 2)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 40, height: 2)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 80, height: 2)
            }
            
            HStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 60)
                
                Rectangle()
                    .fill(Color.ui.lightBlueBackground)
                    .frame(width: 100, height: 60)
                
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 60)
                
                Rectangle()
                    .fill(Color.ui.lightSuccessBackground)
                    .frame(width: 80, height: 60)
                
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 60)
            }
            
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 80, height: 2)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 40, height: 2)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 80, height: 2)
            }
        }
    }
}

struct EngineeringTemplatePreview: View {
    var body: some View {
        VStack {
            HStack {
                VStack(spacing: 2) {
                    Circle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: 40, height: 40)
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 60, height: 1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 80, height: 1)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 60, height: 1)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 40, height: 1)
                }
                .background(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: 90, height: 30)
                )
            }
            
            Spacer()
        }
        .padding()
    }
}

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

#Preview {
    TemplateSelectionView(
        isPresented: .constant(true),
        onTemplateSelected: { _ in }
    )
} 