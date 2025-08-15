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
    var freehandSmoothingTolerance: Double = 2.0
    var brushThickness: Double = 10.0
    var brushPressureSensitivity: Double = 0.5
    var brushTaper: Double = 0.3
    
    // Advanced Smoothing Settings
    var advancedSmoothingEnabled: Bool = true
    var chaikinSmoothingIterations: Int = 1
    var realTimeSmoothingEnabled: Bool = true
    var realTimeSmoothingStrength: Double = 0.3
    var adaptiveTensionEnabled: Bool = true
    var preserveSharpCorners: Bool = true
    
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
            backgroundColor: backgroundColor,
            freehandSmoothingTolerance: freehandSmoothingTolerance,
            brushThickness: brushThickness,
            brushPressureSensitivity: brushPressureSensitivity,
            brushTaper: brushTaper,
            advancedSmoothingEnabled: advancedSmoothingEnabled,
            chaikinSmoothingIterations: chaikinSmoothingIterations,
            realTimeSmoothingEnabled: realTimeSmoothingEnabled,
            realTimeSmoothingStrength: realTimeSmoothingStrength,
            adaptiveTensionEnabled: adaptiveTensionEnabled,
            preserveSharpCorners: preserveSharpCorners
        )
    }
}

// MARK: - Main Document Setup View
struct NewDocumentSetupView: View {
    @Binding var isPresented: Bool
    let onDocumentCreated: (VectorDocument, URL?) -> Void
    
    @State private var setupData = DocumentSetupData()
    // Removed Template preset UI
    @State private var documentPreview: NSImage?
    @State private var isGeneratingPreview = false
    // Skip the very next unit conversion triggered by a programmatic unit change (e.g., Quick Size)
    @State private var skipNextUnitConversion = false
    @Environment(AppState.self) private var appState
    @Environment(\.dismissWindow) private var dismissWindow
    
    // Removed TemplateManager usage
    
    var body: some View {
            VStack(spacing: 0) {
            // Professional Header (compact, clean)
            professionalHeader
            
            // Main Content
            HStack(spacing: 0) {
                // Left Panel - Settings
                settingsPanel
                
                // Visual Separator
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1)
                
                // Right Panel - Preview
                previewPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Professional Footer (compact, clean)
            professionalFooter
        }
        .background(Color.ui.windowBackground)
        .onAppear {
            generateDocumentPreview()
        }
    }
    
    // MARK: - Professional Header
    private var professionalHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // App Icon and Title
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Document")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Create a new vector document with professional settings")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Close Button
                Button(action: { dismissWindow() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Cancel")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
        }
        .background(Color.ui.controlBackground)
    }
    
    // MARK: - Settings Panel
    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Document Name Section
                documentNameSection

                // Document Size directly under name (requested)
                documentSizeSection

                // Quick Sizes Section
                quickSizesSection

                // Advanced Settings removed per request
            }
            .padding(24)
        }
        .frame(width: 450)
        .background(Color.ui.controlBackground)
    }
    
    // MARK: - Document Name Section
    private var documentNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Document Name")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter document name", text: $setupData.filename)
                    .textFieldStyle(ProfessionalTextFieldStyle())
                    .onChange(of: setupData.filename) { _, _ in generateDocumentPreview() }
                
                Text("File will be saved as: \(setupData.filename.isEmpty ? "Untitled" : setupData.filename).inkpen")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Document Size Section
    private var documentSizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ruler")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Document Size")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 16) {
                // Dimensions
                HStack(spacing: 16) {
                    // Width
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("Width", value: $setupData.width, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 100)
                            
                            Text(unitLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Height
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Height")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("Height", value: $setupData.height, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 100)
                            
                            Text(unitLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Units moved to the right column
            }
        }
        .onChange(of: setupData.width) { _, _ in generateDocumentPreview() }
        .onChange(of: setupData.height) { _, _ in generateDocumentPreview() }
        .onChange(of: setupData.unit) { oldUnit, newUnit in
            // If the unit change was triggered by a quick size, skip exactly one conversion
            if skipNextUnitConversion {
                skipNextUnitConversion = false
                generateDocumentPreview()
                return
            }

            let convertedWidth = UnitsConverter.convert(value: setupData.width, from: oldUnit, to: newUnit)
            let convertedHeight = UnitsConverter.convert(value: setupData.height, from: oldUnit, to: newUnit)
            setupData.width = convertedWidth
            setupData.height = convertedHeight
            generateDocumentPreview()
        }
    }
    
    // MARK: - Quick Sizes Section
    private var quickSizesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                Text("Quick Sizes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(quickSizes, id: \.self) { size in
                    ProfessionalQuickSizeButton(size: size, displayUnit: setupData.unit) {
                        applyQuickSize(size)
                    }
                }
            }
        }
    }
    
    // Advanced settings section removed per request
    
    // MARK: - Preview Panel
    private var previewPanel: some View {
             VStack(spacing: 24) {
            // Document Preview
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text("Document Preview")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                VStack(spacing: 16) {
                    // Preview Image
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .frame(width: 210, height: 210)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        if let preview = documentPreview {
                            Image(nsImage: preview)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 195, maxHeight: 195)
                        } else if isGeneratingPreview {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating preview...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "doc")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("Preview not available")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Document Info
                    VStack(spacing: 8) {
                        Text("\(formatNumberForDisplay(setupData.width)) × \(formatNumberForDisplay(setupData.height)) \(setupData.unit.rawValue)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("\(setupData.colorMode.rawValue.uppercased()) • \(Int(setupData.resolution)) DPI")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Units + Color Mode + Resolution on the right (requested)
            VStack(alignment: .leading, spacing: 16) {
                // Units
                VStack(alignment: .leading, spacing: 6) {
                    Text("Units")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Picker("Unit", selection: $setupData.unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // Color Mode and Resolution
                HStack(spacing: 20) {
                    // Color Mode
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Color Mode")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Picker("Color Mode", selection: $setupData.colorMode) {
                            ForEach(ColorMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue.uppercased()).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Resolution
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resolution")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            TextField("Resolution", value: $setupData.resolution, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 80)
                            Text("DPI")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Professional Footer
    private var professionalFooter: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismissWindow()
                }
                .buttonStyle(ProfessionalSecondaryButtonStyle())
                
                Button("Create Document") {
                    createDocument()
                }
                .buttonStyle(ProfessionalPrimaryButtonStyle())
                .disabled(setupData.filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.ui.controlBackground)
    }
    
    // MARK: - Helper Properties
    private var unitLabel: String {
        setupData.unit.rawValue
    }
    
    private var quickSizes: [QuickSize] {
        [
            QuickSize(name: "Letter", baseWidth: 8.5, baseHeight: 11.0, baseUnit: .inches),
            QuickSize(name: "Legal", baseWidth: 8.5, baseHeight: 14.0, baseUnit: .inches),
            // Requested: make A4 be Letter Wide (landscape letter)
            QuickSize(name: "Letter Wide", baseWidth: 11.0, baseHeight: 8.5, baseUnit: .inches),
            QuickSize(name: "Business Card", baseWidth: 3.5, baseHeight: 2.0, baseUnit: .inches),
            QuickSize(name: "Web HD", baseWidth: 1920, baseHeight: 1080, baseUnit: .pixels),
            QuickSize(name: "Mobile", baseWidth: 375, baseHeight: 812, baseUnit: .pixels),
            QuickSize(name: "Square", baseWidth: 1000, baseHeight: 1000, baseUnit: .pixels),
            QuickSize(name: "Wide", baseWidth: 1920, baseHeight: 1080, baseUnit: .pixels)
        ]
    }
    
    // MARK: - Helper Functions
    // Removed template application function
    
    private func applyQuickSize(_ size: QuickSize) {
        // Apply dimensions in the CURRENTLY SELECTED unit to avoid any double conversions
        let targetUnit = setupData.unit
        setupData.width = UnitsConverter.convert(value: size.baseWidth, from: size.baseUnit, to: targetUnit)
        setupData.height = UnitsConverter.convert(value: size.baseHeight, from: size.baseUnit, to: targetUnit)
        
        // Do not force a unit change; optionally set a sensible DPI default if the user is in Pixels
        // Keep existing resolution unless the user explicitly changes it
        generateDocumentPreview()
    }
    
    private func generateDocumentPreview() {
        isGeneratingPreview = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Create a simple preview image
            let previewSize = CGSize(width: 280, height: 280)
            let image = NSImage(size: previewSize)
            
            image.lockFocus()
            
            // Background
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: previewSize).fill()
            
            // Calculate document bounds within preview
            let aspectRatio = setupData.width / setupData.height
            let maxSize: CGFloat = 240
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
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
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
        
        // Apply the user's default tool setting
        document.currentTool = appState.defaultTool
        Log.info("🛠️ Applied default tool \(appState.defaultTool.rawValue) to new document from setup", category: .general)
        
        // Create a suggested URL for the document
        let filename = setupData.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let suggestedURL = documentsPath?.appendingPathComponent("\(filename).inkpen")
        
        onDocumentCreated(document, suggestedURL)
        isPresented = false
    }
}

// MARK: - Quick Size Model
struct QuickSize: Hashable {
    let name: String
    let baseWidth: Double
    let baseHeight: Double
    let baseUnit: MeasurementUnit
}

// MARK: - Professional Quick Size Button Component
struct ProfessionalQuickSizeButton: View {
    let size: QuickSize
    let displayUnit: MeasurementUnit
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                VStack(spacing: 2) {
                    Text(size.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(displayText)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .help("\(displayText) \(displayUnit.rawValue)")
    }
    
    private var iconName: String {
        switch size.name {
        case "Letter", "Legal", "Letter Wide":
            return "doc.text"
        case "Business Card":
            return "creditcard"
        case "Web HD", "Wide":
            return "display"
        case "Mobile":
            return "iphone"
        case "Square":
            return "square"
        default:
            return "doc"
        }
    }

    private var displayText: String {
        let w = UnitsConverter.convert(value: size.baseWidth, from: size.baseUnit, to: displayUnit)
        let h = UnitsConverter.convert(value: size.baseHeight, from: size.baseUnit, to: displayUnit)
        return "\(Int(w))×\(Int(h))"
    }
}

// MARK: - Professional Toggle Component
struct ProfessionalToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - Professional Button Styles
struct ProfessionalPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ProfessionalSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Professional Text Field Style
struct ProfessionalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.ui.textBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Preview
#Preview {
    NewDocumentSetupView(
        isPresented: .constant(true),
        onDocumentCreated: { _, _ in }
    )
} 
