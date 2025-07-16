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


















// MARK: - Professional CMYK Input Section

struct CMYKInputSection: View {
    @ObservedObject var document: VectorDocument
    @State private var cyanValue: String = "0"
    @State private var magentaValue: String = "0"
    @State private var yellowValue: String = "0"
    @State private var blackValue: String = "0"
    @State private var previewColor: CMYKColor = CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CMYK Process Colors")
                    .font(.caption)
                .fontWeight(.medium)
                    .foregroundColor(.secondary)
            
            Text("Enter process color values (0-100%)")
                .font(.caption2)
                    .foregroundColor(.secondary)
            
            // CMYK Input Grid
            VStack(spacing: 6) {
                // Cyan and Magenta row
                HStack(spacing: 8) {
                    CMYKInputField(
                        label: "C",
                        value: $cyanValue,
                        color: .cyan,
                        onChange: updatePreview
                    )
                    
                    CMYKInputField(
                        label: "M",
                        value: $magentaValue,
                        color: .pink,
                        onChange: updatePreview
                    )
                }
                
                // Yellow and Black row
                HStack(spacing: 8) {
                    CMYKInputField(
                        label: "Y",
                        value: $yellowValue,
                        color: .yellow,
                        onChange: updatePreview
                    )
                    
                    CMYKInputField(
                        label: "K",
                        value: $blackValue,
                        color: .black,
                        onChange: updatePreview
                    )
                }
            }
            
            // Color Preview and Add Button
            HStack(spacing: 8) {
                // Preview
                Rectangle()
                    .fill(previewColor.color)
                    .frame(width: 40, height: 30)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .cornerRadius(4)
                
                VStack(alignment: .leading, spacing: 2) {
                                                    Text("CMYK(\(Int((previewColor.cyan * 100).isFinite ? previewColor.cyan * 100 : 0)), \(Int((previewColor.magenta * 100).isFinite ? previewColor.magenta * 100 : 0)), \(Int((previewColor.yellow * 100).isFinite ? previewColor.yellow * 100 : 0)), \(Int((previewColor.black * 100).isFinite ? previewColor.black * 100 : 0)))")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    
                    Button("Add to Swatches") {
                        addCMYKColorToSwatches()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    .controlSize(.small)
                }
                
                Spacer()
            }
            
            // Quick CMYK Presets
        VStack(alignment: .leading, spacing: 4) {
                Text("Common Process Colors")
                    .font(.caption2)
                .foregroundColor(.secondary)
            
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    CMYKPresetButton(name: "Cyan", cmyk: (100, 0, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Magenta", cmyk: (0, 100, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Yellow", cmyk: (0, 0, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Black", cmyk: (0, 0, 0, 100), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Red", cmyk: (0, 100, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Green", cmyk: (100, 0, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Blue", cmyk: (100, 100, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Rich Black", cmyk: (30, 30, 30, 100), action: applyCMYKPreset)
                }
            }
        }
        .onAppear {
            updatePreview()
        }
    }
    
    private func updatePreview() {
        let c = (Double(cyanValue) ?? 0) / 100.0
        let m = (Double(magentaValue) ?? 0) / 100.0
        let y = (Double(yellowValue) ?? 0) / 100.0
        let k = (Double(blackValue) ?? 0) / 100.0
        
        previewColor = CMYKColor(
            cyan: max(0, min(1, c)),
            magenta: max(0, min(1, m)),
            yellow: max(0, min(1, y)),
            black: max(0, min(1, k))
        )
    }
    
    private func addCMYKColorToSwatches() {
        let vectorColor = VectorColor.cmyk(previewColor)
        document.addColorSwatch(vectorColor)
    }
    
    private func applyCMYKPreset(_ cmyk: (Int, Int, Int, Int)) {
        cyanValue = String(cmyk.0)
        magentaValue = String(cmyk.1)
        yellowValue = String(cmyk.2)
        blackValue = String(cmyk.3)
        updatePreview()
    }
}

struct CMYKInputField: View {
    let label: String
    @Binding var value: String
    let color: Color
    let onChange: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
        HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            TextField("0", text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.caption)
                .frame(height: 24)
                .onChange(of: value) { oldValue, newValue in
                    // Validate and clamp input to 0-100
                    if let numValue = Double(newValue) {
                        if numValue < 0 {
                            value = "0"
                        } else if numValue > 100 {
                            value = "100"
                        }
                    }
                    onChange()
                }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CMYKPresetButton: View {
    let name: String
    let cmyk: (Int, Int, Int, Int)
    let action: ((Int, Int, Int, Int)) -> Void
    
    var body: some View {
        Button {
            action(cmyk)
        } label: {
            VStack(spacing: 2) {
                let cmykColor = CMYKColor(
                    cyan: Double(cmyk.0) / 100.0,
                    magenta: Double(cmyk.1) / 100.0,
                    yellow: Double(cmyk.2) / 100.0,
                    black: Double(cmyk.3) / 100.0
                )
                
                        Rectangle()
                    .fill(cmykColor.color)
                    .frame(height: 20)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: 0.5)
                    )
                    .cornerRadius(3)
                
                Text(name)
                    .font(.system(size: 8))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help("CMYK(\(cmyk.0), \(cmyk.1), \(cmyk.2), \(cmyk.3))")
    }
}

// MARK: - Professional Pantone Color Picker Sheet

struct PantoneColorPickerSheet: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchText = ""
    @State private var selectedCategory: PantoneCategory = .all
    @State private var selectedColor: PantoneColor?
    
    enum PantoneCategory: String, CaseIterable {
        case all = "All Colors"
        case classics = "Classic Colors"
        case metallics = "Metallics"
        case colorOfYear = "Color of the Year"
        
        func filter(_ colors: [PantoneColor]) -> [PantoneColor] {
            switch self {
            case .all:
                return colors
            case .classics:
                return colors.filter { color in
                    color.number.contains("C") && 
                    !color.name.localizedCaseInsensitiveContains("metallic") &&
                    !color.name.localizedCaseInsensitiveContains("peach fuzz")
                }
            case .metallics:
                return colors.filter { $0.number.contains("871") || $0.number.contains("877") }
            case .colorOfYear:
                return colors.filter { $0.name.localizedCaseInsensitiveContains("peach fuzz") }
            }
        }
    }
    
    private var allPantoneColors: [PantoneColor] {
        ColorManagement.loadPantoneColors()
    }
    
    private var filteredColors: [PantoneColor] {
        let categoryFiltered = selectedCategory.filter(allPantoneColors)
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { color in
                color.name.localizedCaseInsensitiveContains(searchText) ||
                color.number.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Search and Filter Section
                VStack(alignment: .leading, spacing: 12) {
                    // Search Bar
            HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search Pantone colors...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Category Filter
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PantoneCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                
                // Selected Color Preview
                if let selectedColor = selectedColor {
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(selectedColor.color)
                            .frame(height: 60)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PANTONE \(selectedColor.number)")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(selectedColor.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("RGB: \(Int(selectedColor.rgbEquivalent.red * 255)), \(Int(selectedColor.rgbEquivalent.green * 255)), \(Int(selectedColor.rgbEquivalent.blue * 255))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
            Spacer()
                            }
                            
                            HStack {
                                Text("CMYK: \(Int((selectedColor.cmykEquivalent.cyan * 100).isFinite ? selectedColor.cmykEquivalent.cyan * 100 : 0))%, \(Int((selectedColor.cmykEquivalent.magenta * 100).isFinite ? selectedColor.cmykEquivalent.magenta * 100 : 0))%, \(Int((selectedColor.cmykEquivalent.yellow * 100).isFinite ? selectedColor.cmykEquivalent.yellow * 100 : 0))%, \(Int((selectedColor.cmykEquivalent.black * 100).isFinite ? selectedColor.cmykEquivalent.black * 100 : 0))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // Color Grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(50), spacing: 8), count: 6), spacing: 8) {
                        ForEach(filteredColors, id: \.number) { color in
                            Button {
                                selectedColor = color
                            } label: {
            VStack(spacing: 4) {
                                    Rectangle()
                                        .fill(color.color)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Rectangle()
                                                .stroke(selectedColor?.number == color.number ? Color.blue : Color.gray, 
                                                       lineWidth: selectedColor?.number == color.number ? 2 : 1)
                                        )
                                    
                                    Text(color.number)
                                        .font(.system(size: 8))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
        }
        .buttonStyle(PlainButtonStyle())
                            .help("PANTONE \(color.number) - \(color.name)")
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Pantone Colors")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Swatches") {
                        if let selectedColor = selectedColor {
                            let vectorColor = VectorColor.pantone(selectedColor)
                            document.addColorSwatch(vectorColor)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(selectedColor == nil)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Select first color by default
            selectedColor = filteredColors.first
        }
        .onChange(of: selectedCategory) { oldValue, newValue in
            selectedColor = filteredColors.first
        }
        .onChange(of: searchText) { oldValue, newValue in
            selectedColor = filteredColors.first
        }
    }
}

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
