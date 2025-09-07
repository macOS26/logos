//
//  DWFExportView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

/// Professional DWF Export Configuration View (Professional Standards)
struct DWFExportView: View {
    @ObservedObject var document: VectorDocument
    @Binding var options: DWFExportOptions
    let onExport: (DWFExportOptions) -> Void
    
    @State private var selectedScale: DWFScale = .fullSize
    @State private var selectedUnits: VectorUnit = .points
    @State private var flipYAxis: Bool = true
    @State private var authorName: String = ""
    @State private var documentTitle: String = ""
    @State private var documentDescription: String = ""
    @State private var customScaleFactor: String = "1.0"
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export to DWF")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Design Web Format for AutoCAD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    // Just dismiss without exporting
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Scale Settings (Professional Section)
                    GroupBox("Scale & Units") {
                        VStack(alignment: .leading, spacing: 16) {
                            // Scale Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Export Scale")
                                    .font(.headline)
                                
                                // Architectural Scales
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Architectural Scales")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                        ForEach([
                                            DWFScale.architectural_1_16,
                                            DWFScale.architectural_1_8,
                                            DWFScale.architectural_1_4,
                                            DWFScale.architectural_1_2,
                                            DWFScale.architectural_1_1
                                        ], id: \.description) { scale in
                                            scaleButton(scale)
                                        }
                                    }
                                }
                                
                                // Engineering Scales
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Engineering Scales")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                        ForEach([
                                            DWFScale.engineering_1_10,
                                            DWFScale.engineering_1_20,
                                            DWFScale.engineering_1_50,
                                            DWFScale.engineering_1_100
                                        ], id: \.description) { scale in
                                            scaleButton(scale)
                                        }
                                    }
                                }
                                
                                // Metric Scales
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Metric Scales")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                        ForEach([
                                            DWFScale.metric_1_100,
                                            DWFScale.metric_1_200,
                                            DWFScale.metric_1_500,
                                            DWFScale.metric_1_1000
                                        ], id: \.description) { scale in
                                            scaleButton(scale)
                                        }
                                    }
                                }
                                
                                // Full Size and Custom
                                HStack {
                                    scaleButton(.fullSize)
                                    
                                    VStack {
                                        Text("Custom")
                                            .font(.caption)
                                        HStack {
                                            TextField("1.0", text: $customScaleFactor)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(width: 60)
                                            Button("Apply") {
                                                if let factor = Double(customScaleFactor) {
                                                    selectedScale = .custom(CGFloat(factor))
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Units Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Units")
                                    .font(.headline)
                                
                                Picker("Units", selection: $selectedUnits) {
                                    Text("Points").tag(VectorUnit.points)
                                    Text("Inches").tag(VectorUnit.inches)
                                    Text("Millimeters").tag(VectorUnit.millimeters)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                        }
                        .padding()
                    }
                    
                    // Coordinate System
                    GroupBox("Coordinate System") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Flip Y-Axis (AutoCAD Standard)", isOn: $flipYAxis)
                                .help("AutoCAD uses a different Y-axis orientation than most graphics software")
                        }
                        .padding()
                    }
                    
                    // Document Information
                    GroupBox("Document Information") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Author")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextField("Author name", text: $authorName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Title")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextField("Document title", text: $documentTitle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextField("Document description (optional)", text: $documentDescription)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        .padding()
                    }
                    
                    // Export Preview
                    GroupBox("Export Preview") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Current Document Size:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(formatSize(document.getDocumentBounds().size))")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Export Scale:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(selectedScale.description)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Target Units:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(selectedUnits.rawValue)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Shape Count:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(getTotalShapeCount())")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
            
            // Export Button
            HStack {
                Spacer()
                
                Button("Export DWF") {
                    let finalOptions = DWFExportOptions(
                        scale: selectedScale,
                        targetUnits: selectedUnits,
                        flipYAxis: flipYAxis,
                        customOrigin: nil,
                        author: authorName.isEmpty ? nil : authorName,
                        title: documentTitle.isEmpty ? nil : documentTitle,
                        description: documentDescription.isEmpty ? nil : documentDescription
                    )
                    
                    onExport(finalOptions)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
        .onAppear {
            // Initialize with current document settings
            selectedUnits = document.documentUnits
            authorName = NSFullUserName()
            documentTitle = "Vector Graphics Export"
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func scaleButton(_ scale: DWFScale) -> some View {
        Button(scale.description) {
            selectedScale = scale
        }
        .buttonStyle(.bordered)
        .background(selectedScale.description == scale.description ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
    
    // MARK: - Helper Functions
    
    private func formatSize(_ size: CGSize) -> String {
        return String(format: "%.1f × %.1f %@", size.width, size.height, selectedUnits.rawValue)
    }
    
    private func getTotalShapeCount() -> Int {
        var count = 0
        for unifiedObject in document.unifiedObjects {
            if case .shape(_) = unifiedObject.objectType {
                count += 1
            }
        }
        return count
    }
}

#Preview {
    DWFExportView(
        document: VectorDocument(),
        options: .constant(DWFExportOptions())
    ) { _ in
        // Preview action
    }
} 