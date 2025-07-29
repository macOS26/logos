//
//  NewDocumentSetupView.swift
//  logos inkpen.io
//
//  Professional Document Creation Window
//

import SwiftUI
import AppKit

// MARK: - Document Setup Data Model
struct DocumentSetupData {
    var width: Double = 11.0
    var height: Double = 8.5
    var unit: MeasurementUnit = .inches
    var filename: String = "Untitled"
    var colorMode: ColorMode = .rgb
    var resolution: Double = 72.0
    var showRulers: Bool = true
    var showGrid: Bool = false
    var snapToGrid: Bool = false
    var backgroundColor: VectorColor = .white
    
    var documentSettings: DocumentSettings {
        DocumentSettings(
            width: width,
            height: height,
            unit: unit,
            colorMode: colorMode,
            resolution: resolution,
            showRulers: showRulers,
            showGrid: showGrid,
            snapToGrid: snapToGrid,
            gridSpacing: 0.125,
            backgroundColor: backgroundColor
        )
    }
}

// MARK: - Main Document Setup View
struct NewDocumentSetupView: View {
    @Binding var isPresented: Bool
    let onDocumentCreated: (VectorDocument, URL?) -> Void
    
    @State private var setupData = DocumentSetupData()
    @State private var selectedTemplate: TemplateManager.TemplateType = .blank
    @State private var showingTemplatePicker = false
    @State private var documentPreview: NSImage?
    @State private var isGeneratingPreview = false
    
    private let templateManager = TemplateManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Content
            HStack(spacing: 0) {
                // Left Panel - Document Settings
                leftPanel
                
                // Divider
                Divider()
                    .frame(width: 1)
                
                // Right Panel - Preview and Templates
                rightPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Footer
            footerSection
        }
        .frame(width: 900, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            generateDocumentPreview()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Document")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Create a new vector document")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
        }
        .padding(24)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Left Panel - Document Settings
    private var leftPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Document Size Section
                documentSizeSection
                
                // Template Section
                templateSection
                
                // Advanced Settings Section
                advancedSettingsSection
            }
            .padding(16)
        }
        .frame(width: 400)
    }
    
    // MARK: - Document Size Section
    private var documentSizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Size")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Width and Height in HStack for compact layout
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Width")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Width", value: $setupData.width, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        
                        Text(unitLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Height")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Height", value: $setupData.height, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        
                        Text(unitLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Unit Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Units")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Unit", selection: $setupData.unit) {
                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .onChange(of: setupData.width) { _, _ in generateDocumentPreview() }
        .onChange(of: setupData.height) { _, _ in generateDocumentPreview() }
        .onChange(of: setupData.unit) { _, _ in generateDocumentPreview() }
    }
    
    // MARK: - Template Section
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Template")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Template Picker and Quick Sizes in HStack for compact layout
            HStack(alignment: .top, spacing: 12) {
                // Template Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preset")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Template", selection: $selectedTemplate) {
                        ForEach(TemplateManager.TemplateType.allCases, id: \.self) { template in
                            Text(template.displayName).tag(template)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedTemplate) { _, newTemplate in
                        applyTemplate(newTemplate)
                    }
                }
                .frame(width: 120)
                
                // Quick Size Buttons in ROWS
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Sizes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Row 1: Letter, Legal, A4, Business Card
                    HStack(spacing: 4) {
                        Button("Letter") {
                            applyQuickSize(quickSizes[0])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        
                        Button("Legal") {
                            applyQuickSize(quickSizes[1])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        
                        Button("A4") {
                            applyQuickSize(quickSizes[2])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        
                        Button("Business Card") {
                            applyQuickSize(quickSizes[3])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Row 2: Web HD, Mobile, Square, Wide
                    HStack(spacing: 4) {
                        Button("Web HD") {
                            applyQuickSize(quickSizes[4])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        
                        Button("Mobile") {
                            applyQuickSize(quickSizes[5])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        
                        Button("Square") {
                            applyQuickSize(quickSizes[6])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        
                        Button("Wide") {
                            applyQuickSize(quickSizes[7])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    
    // MARK: - Advanced Settings Section
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Advanced Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Advanced settings in HStack for compact layout
            HStack(alignment: .top, spacing: 16) {
                // Color Mode and Resolution
                VStack(alignment: .leading, spacing: 8) {
                    // Color Mode
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Color Mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Color Mode", selection: $setupData.colorMode) {
                            ForEach(ColorMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Resolution
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resolution")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("Resolution", value: $setupData.resolution, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                            
                            Text("DPI")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Display Options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("Show Rulers", isOn: $setupData.showRulers)
                    Toggle("Show Grid", isOn: $setupData.showGrid)
                    Toggle("Snap to Grid", isOn: $setupData.snapToGrid)
                        .disabled(!setupData.showGrid)
                }
            }
        }
    }
    
    // MARK: - Right Panel - Preview and Filename
    private var rightPanel: some View {
        VStack(spacing: 16) {
            // Filename Section
            filenameSection
            
            // Preview Section
            previewSection
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Filename Section
    private var filenameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Name")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Filename")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Document name", text: $setupData.filename)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: setupData.filename) { _, _ in generateDocumentPreview() }
                
                Text("File will be saved as: \(setupData.filename).inkpen")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Preview")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                // Document Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: 200, height: 200)
                    
                    if let preview = documentPreview {
                        Image(nsImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 180, maxHeight: 180)
                    } else if isGeneratingPreview {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "doc")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Document Info
                VStack(spacing: 4) {
                    Text("\(formatNumberForDisplay(setupData.width)) × \(formatNumberForDisplay(setupData.height)) \(setupData.unit.rawValue)")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("\(setupData.colorMode.rawValue) • \(Int(setupData.resolution)) DPI")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Create Document") {
                    createDocument()
                }
                .buttonStyle(.borderedProminent)
                .disabled(setupData.filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helper Properties
    private var unitLabel: String {
        setupData.unit.rawValue
    }
    
    private var quickSizes: [(name: String, width: Double, height: Double, unit: MeasurementUnit)] {
        [
            ("Letter", 8.5, 11.0, .inches),
            ("Legal", 8.5, 14.0, .inches),
            ("A4", 8.27, 11.69, .inches),
            ("Business Card", 3.5, 2.0, .inches),
            ("Web HD", 1920, 1080, .pixels),
            ("Mobile", 375, 812, .pixels),
            ("Square", 1000, 1000, .pixels),
            ("Wide", 1920, 1080, .pixels)
        ]
    }
    
    // MARK: - Helper Functions
    private func applyTemplate(_ template: TemplateManager.TemplateType) {
        let templateDoc = templateManager.createDocumentFromTemplate(template)
        setupData.width = templateDoc.settings.width
        setupData.height = templateDoc.settings.height
        setupData.unit = templateDoc.settings.unit
        setupData.colorMode = templateDoc.settings.colorMode
        setupData.resolution = templateDoc.settings.resolution
        setupData.showRulers = templateDoc.settings.showRulers
        setupData.showGrid = templateDoc.settings.showGrid
        setupData.snapToGrid = templateDoc.settings.snapToGrid
        setupData.backgroundColor = templateDoc.settings.backgroundColor
        
        generateDocumentPreview()
    }
    
    private func applyQuickSize(_ size: (name: String, width: Double, height: Double, unit: MeasurementUnit)) {
        setupData.width = size.width
        setupData.height = size.height
        setupData.unit = size.unit
        
        // Adjust resolution based on unit
        if size.unit == .pixels {
            setupData.resolution = 72.0
        } else {
            setupData.resolution = 300.0
        }
        
        generateDocumentPreview()
    }
    
    private func generateDocumentPreview() {
        isGeneratingPreview = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Create a simple preview image
            let previewSize = CGSize(width: 200, height: 200)
            let image = NSImage(size: previewSize)
            
            image.lockFocus()
            
            // Background
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: previewSize).fill()
            
            // Calculate document bounds within preview
            let aspectRatio = setupData.width / setupData.height
            let maxSize: CGFloat = 160
            let docWidth: CGFloat
            let docHeight: CGFloat
            
            if aspectRatio > 1 {
                docWidth = maxSize
                docHeight = maxSize / aspectRatio
            } else {
                docHeight = maxSize
                docWidth = maxSize * aspectRatio
            }
            
            let docRect = CGRect(
                x: (previewSize.width - docWidth) / 2,
                y: (previewSize.height - docHeight) / 2,
                width: docWidth,
                height: docHeight
            )
            
            // Document background
            NSColor.white.setFill()
            docRect.fill()
            
            // Document border
            NSColor.gray.setStroke()
            NSBezierPath(rect: docRect).stroke()
            
            // Document info text
            let infoText = "\(Int(setupData.width))×\(Int(setupData.height))"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.gray
            ]
            
            let textSize = infoText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: docRect.midX - textSize.width / 2,
                y: docRect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            infoText.draw(in: textRect, withAttributes: attributes)
            
            image.unlockFocus()
            
            DispatchQueue.main.async {
                self.documentPreview = image
                self.isGeneratingPreview = false
            }
        }
    }
    
    private func createDocument() {
        let document = VectorDocument(settings: setupData.documentSettings)
        
        // Create a suggested URL for the document
        let filename = setupData.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let suggestedURL = documentsPath?.appendingPathComponent("\(filename).inkpen")
        
        onDocumentCreated(document, suggestedURL)
        isPresented = false
    }
}

// MARK: - Preview
#Preview {
    NewDocumentSetupView(
        isPresented: .constant(true),
        onDocumentCreated: { _, _ in }
    )
} 