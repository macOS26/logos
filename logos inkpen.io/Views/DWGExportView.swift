//
//  DWGExportView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

/// Professional DWG Export Configuration View (Adobe Illustrator Standards for AutoCAD)
struct DWGExportView: View {
    @ObservedObject var document: VectorDocument
    @Binding var options: DWGExportOptions
    let onExport: (DWGExportOptions) -> Void
    
    @State private var selectedScale: DWGScale = .fullSize
    @State private var selectedUnits: VectorUnit = .points
    @State private var flipYAxis: Bool = true
    @State private var authorName: String = ""
    @State private var documentTitle: String = ""
    @State private var documentDescription: String = ""
    @State private var customScaleFactor: String = "1.0"
    @State private var selectedDWGVersion: DWGVersion = .r2018
    @State private var includeReferenceRectangle: Bool = true
    @State private var selectedLineType: DWGLineType = .continuous
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export to DWG")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Adobe Illustrator Standards for AutoCAD Compatibility")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Professional Scale Configuration (Adobe Illustrator Method)
                    GroupBox("Professional Scale Configuration") {
                        VStack(spacing: 16) {
                            
                            HStack {
                                Text("Scale Type:")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            // Scale Selection (Adobe Illustrator / AutoCAD Standards)
                            VStack(alignment: .leading, spacing: 12) {
                                
                                // Architectural Scales
                                Text("Architectural (Adobe Illustrator / AutoCAD)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    DWGScaleButton(scale: .architectural_1_16, selection: $selectedScale)
                                    DWGScaleButton(scale: .architectural_1_8, selection: $selectedScale)
                                    DWGScaleButton(scale: .architectural_1_4, selection: $selectedScale)
                                    DWGScaleButton(scale: .architectural_1_2, selection: $selectedScale)
                                    DWGScaleButton(scale: .architectural_1_1, selection: $selectedScale)
                                    DWGScaleButton(scale: .fullSize, selection: $selectedScale)
                                }
                                
                                Divider()
                                
                                // Engineering Scales
                                Text("Engineering (AutoCAD Standard)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    DWGScaleButton(scale: .engineering_1_10, selection: $selectedScale)
                                    DWGScaleButton(scale: .engineering_1_20, selection: $selectedScale)
                                    DWGScaleButton(scale: .engineering_1_50, selection: $selectedScale)
                                    DWGScaleButton(scale: .engineering_1_100, selection: $selectedScale)
                                }
                                
                                Divider()
                                
                                // Metric Scales
                                Text("Metric (International Standard)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    DWGScaleButton(scale: .metric_1_100, selection: $selectedScale)
                                    DWGScaleButton(scale: .metric_1_200, selection: $selectedScale)
                                    DWGScaleButton(scale: .metric_1_500, selection: $selectedScale)
                                    DWGScaleButton(scale: .metric_1_1000, selection: $selectedScale)
                                }
                                
                                // Custom Scale
                                if case .custom(_) = selectedScale {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Custom Scale Factor:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        TextField("Enter scale factor", text: $customScaleFactor)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .help("Enter custom scale factor (e.g., 0.5 for half size)")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Units and Coordinate System (AutoCAD Compatibility)
                    GroupBox("Units & Coordinate System") {
                        VStack(spacing: 16) {
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Units (AutoCAD Standard):")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Units", selection: $selectedUnits) {
                                    Text("Points").tag(VectorUnit.points)
                                    Text("Inches").tag(VectorUnit.inches)
                                    Text("Millimeters").tag(VectorUnit.millimeters)
                                    Text("Pixels").tag(VectorUnit.pixels)
                                    Text("Picas").tag(VectorUnit.picas)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Coordinate System:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Toggle("Flip Y-Axis (AutoCAD Standard)", isOn: $flipYAxis)
                                    .help("AutoCAD uses inverted Y-axis compared to screen coordinates")
                                
                                Toggle("Include Reference Rectangle", isOn: $includeReferenceRectangle)
                                    .help("Adobe Illustrator method: adds reference rectangle for scaling verification")
                            }
                        }
                        .padding()
                    }
                    
                    // AutoCAD Compatibility Settings
                    GroupBox("AutoCAD Compatibility") {
                        VStack(spacing: 16) {
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("DWG Version:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Version", selection: $selectedDWGVersion) {
                                    ForEach(DWGVersion.allCases, id: \.self) { version in
                                        Text(version.displayName).tag(version)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Default Line Type:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Line Type", selection: $selectedLineType) {
                                    ForEach(DWGLineType.allCases, id: \.self) { lineType in
                                        Text(lineType.description).tag(lineType)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                        }
                        .padding()
                    }
                    
                    // Document Information (Professional Metadata)
                    GroupBox("Document Information") {
                        VStack(spacing: 16) {
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Author:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter author name", text: $authorName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter document title", text: $documentTitle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter description (optional)", text: $documentDescription)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        .padding()
                    }
                    
                    // Export Summary
                    GroupBox("Export Summary") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Scale:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(selectedScale.description)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Units:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(selectedUnits.rawValue.uppercased())
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("DWG Version:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(selectedDWGVersion.displayName)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Shapes:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(document.getTotalShapeCount())")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Layers:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(document.layers.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                }
                .padding(.horizontal)
            }
            
            // Export Controls
            HStack(spacing: 16) {
                Button("Cancel") {
                    // Close without exporting
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Export DWG") {
                    // Create final export options
                    let finalScale: DWGScale
                    if case .custom(_) = selectedScale,
                       let customFactor = Double(customScaleFactor) {
                        finalScale = .custom(CGFloat(customFactor))
                    } else {
                        finalScale = selectedScale
                    }
                    
                    let finalOptions = DWGExportOptions(
                        scale: finalScale,
                        targetUnits: selectedUnits,
                        flipYAxis: flipYAxis,
                        customOrigin: nil,
                        author: authorName.isEmpty ? nil : authorName,
                        title: documentTitle.isEmpty ? nil : documentTitle,
                        description: documentDescription.isEmpty ? nil : documentDescription,
                        dwgVersion: selectedDWGVersion,
                        includeReferenceRectangle: includeReferenceRectangle,
                        defaultLineType: selectedLineType
                    )
                    
                    onExport(finalOptions)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(document.getTotalShapeCount() == 0)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 600, height: 700)
        .onAppear {
            // Initialize values from current options
            selectedScale = options.scale
            selectedUnits = options.targetUnits
            flipYAxis = options.flipYAxis
            authorName = options.author ?? ""
            documentTitle = options.title ?? ""
            documentDescription = options.description ?? ""
            selectedDWGVersion = options.dwgVersion
            includeReferenceRectangle = options.includeReferenceRectangle
            selectedLineType = options.defaultLineType
        }
    }
}

/// Professional Scale Selection Button for DWG Export
struct DWGScaleButton: View {
    let scale: DWGScale
    @Binding var selection: DWGScale
    
    var isSelected: Bool {
        switch (scale, selection) {
        case (.architectural_1_16, .architectural_1_16),
             (.architectural_1_8, .architectural_1_8),
             (.architectural_1_4, .architectural_1_4),
             (.architectural_1_2, .architectural_1_2),
             (.architectural_1_1, .architectural_1_1),
             (.engineering_1_10, .engineering_1_10),
             (.engineering_1_20, .engineering_1_20),
             (.engineering_1_50, .engineering_1_50),
             (.engineering_1_100, .engineering_1_100),
             (.metric_1_100, .metric_1_100),
             (.metric_1_200, .metric_1_200),
             (.metric_1_500, .metric_1_500),
             (.metric_1_1000, .metric_1_1000),
             (.fullSize, .fullSize):
            return true
        case (.custom(_), .custom(_)):
            return true
        default:
            return false
        }
    }
    
    var body: some View {
        Button(action: {
            selection = scale
        }) {
            Text(scale.description)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DWGExportView(
        document: VectorDocument(),
        options: .constant(DWGExportOptions()),
        onExport: { _ in }
    )
} 