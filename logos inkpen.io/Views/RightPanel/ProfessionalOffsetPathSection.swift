//
//  ProfessionalOffsetPathSection.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Professional Offset Path Section (Adobe Illustrator Standards)

struct ProfessionalOffsetPathSection: View {
    @ObservedObject var document: VectorDocument
    @State private var offsetDistance: Double = 10.0
    @State private var selectedJoinType: JoinType = .round
    @State private var miterLimit: Double = 4.0
    @State private var showAdvanced: Bool = true
    @State private var keepOriginalPath: Bool = true
    @State private var cleanupOverlaps: Bool = false

    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with disclosure triangle
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Offset Path")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Adobe Illustrator icon
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            if showAdvanced {
                VStack(alignment: .leading, spacing: 10) {
                    // Offset Distance Control
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Offset:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(offsetDistance, specifier: "%.1f") pt")
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: $offsetDistance, in: -50...50, step: 0.5) {
                            Text("Offset Distance")
                        }
                        .controlSize(.small)
                        .tint(.blue)
                    }
                    
                    // Keep Original Path Checkbox (Adobe Illustrator Standard)
                    HStack {
                        Button {
                            keepOriginalPath.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: keepOriginalPath ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 14))
                                    .foregroundColor(keepOriginalPath ? .blue : .secondary)
                                
                                Text("Keep Original Path")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Keep the original path when creating offset (Adobe Illustrator default)")
                        
                        Spacer()
                    }
                    
                    // TrimX Checkbox (Professional cleanup for complex shapes)
                    HStack {
                        Button {
                            cleanupOverlaps.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cleanupOverlaps ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 14))
                                    .foregroundColor(cleanupOverlaps ? .blue : .secondary)
                                
                                Text("TrimX")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Clean up offset results using Trim operation between original and result")
                        
                        Spacer()
                    }
                    
                    // Join Type Selection (Adobe Illustrator style)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Joins:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            ForEach([JoinType.round, .square, .bevel, .miter], id: \.self) { joinType in
                                Button {
                                    selectedJoinType = joinType
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: joinType.iconName)
                                            .font(.system(size: 12))
                                        
                                        Text(joinType.displayName)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(selectedJoinType == joinType ? .accentColor : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedJoinType == joinType ? Color.accentColor.opacity(0.1) : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(selectedJoinType == joinType ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                            )
                                    )
                                    .contentShape(Rectangle()) // Extend hit area to match entire button background
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help(joinType.description)
                            }
                        }
                    }
                    
                    // Miter Limit (only show for miter joins)
                    if selectedJoinType == .miter {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Miter Limit:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(miterLimit, specifier: "%.1f")")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $miterLimit, in: 1.0...20.0, step: 0.1) {
                                Text("Miter Limit")
                            }
                            .controlSize(.small)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    

                    
                    // Action Buttons (Adobe Illustrator style)
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            // Offset Path button (handles both positive and negative offsets)
                            Button("Offset Path") {
                                performOffsetPath()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .help("Create offset path with current settings (⌘⌥O)")
                            .disabled(!canPerformOffset())
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 6) {
                            // Quick presets
                            Button("−10pt") {
                                offsetDistance = -10.0
                                performOffsetPath()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(!canPerformOffset())
                            
                            Button("+10pt") {
                                offsetDistance = 10.0
                                performOffsetPath()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(!canPerformOffset())
                            
                            Button("Reset") {
                                resetToDefaults()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func canPerformOffset() -> Bool {
        return !document.selectedShapeIDs.isEmpty
    }
    

    
    private func performOffsetPath() {
        guard !document.selectedShapeIDs.isEmpty else { return }
        
        print("🎨 PROFESSIONAL OFFSET PATH: \(offsetDistance)pt, join: \(selectedJoinType)")
        
        // Save to undo stack
        document.saveToUndoStack()
        
        // Get selected shapes
        let selectedShapes = document.getSelectedShapes()
        var newOffsetShapeIDs: Set<UUID> = []
        
        for shape in selectedShapes {
            // Use STROKE-BASED OFFSET for perfect smooth curves (no more Clipper polygons!)
            let effectiveMiterLimit = selectedJoinType == .square ? 1.0 : CGFloat(miterLimit)
            let strokeOptions = StrokeBasedOffsetOptions(
                offset: CGFloat(offsetDistance),
                joinType: mapJoinTypeToCoreGraphics(selectedJoinType),
                endType: .round,
                miterLimit: effectiveMiterLimit,
                keepOriginal: keepOriginalPath
            )
            
            // Create perfect smooth offset using Core Graphics strokes + expand
            var offsetPaths = shape.path.cgPath.strokeBasedOffset(strokeOptions)
            
            // Apply CutX cleanup if requested (professional cut operation)
            if cleanupOverlaps && !offsetPaths.isEmpty {
                // CutX Formula: Take result and original path, run "Cut", return the outside cleaned path
                for (index, offsetPath) in offsetPaths.enumerated() {
                    let pathsToCut = [shape.path.cgPath, offsetPath]
                    let cutPaths = ProfessionalPathOperations.professionalCut(pathsToCut)
                    
                    // Find the outside path (usually the largest one after cut)
                    if let outsidePath = findOutsidePath(from: cutPaths, original: shape.path.cgPath, offset: offsetPath) {
                        offsetPaths[index] = outsidePath
                        print("🔧 CUTX: Applied cut operation and selected outside cleaned path")
                    }
                }
            }
            
            // Convert results back to VectorShapes (now working with CGPaths directly!)
            for (index, offsetCGPath) in offsetPaths.enumerated() {
                let offsetVectorPath = VectorPath(cgPath: offsetCGPath)
                
                let offsetShape = VectorShape(
                    name: "\(shape.name) Offset \(offsetDistance > 0 ? "+" : "")\(offsetDistance)pt\(index > 0 ? " \(index + 1)" : "")",
                    path: offsetVectorPath,
                    strokeStyle: shape.strokeStyle,
                    fillStyle: shape.fillStyle,
                    transform: shape.transform,
                    opacity: shape.opacity
                )
                
                // Add to document (will be moved behind original later)
                document.addShape(offsetShape)
                newOffsetShapeIDs.insert(offsetShape.id)
            }
            
        }
        
        // Move offset shapes behind originals (Adobe Illustrator standard)
        if keepOriginalPath {
            // Send offset shapes to back so they appear behind the originals
            document.sendSelectedToBack()
        } else {
            // Remove original shapes if not keeping them
            document.removeSelectedShapes()
        }
        
        // Always select the result of the offset path operation
        document.selectedShapeIDs = newOffsetShapeIDs
        
        // Force document refresh so arrow tool can see newly created shapes
        document.objectWillChange.send()
         
         print("✅ OFFSET PATH: Created offset shapes \(keepOriginalPath ? "behind" : "replacing") originals")
    }
    

    
    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.2)) {
            offsetDistance = 10.0
            selectedJoinType = .miter
            miterLimit = 4.0
            keepOriginalPath = true
            cleanupOverlaps = false
        }
    }
    
    private func mapJoinTypeToCoreGraphics(_ joinType: JoinType) -> CGLineJoin {
        switch joinType {
        case .round: return .round
        case .miter: return .miter
        case .bevel: return .bevel
        case .square: return .miter  // Square corners with minimal miter limit
        }
    }
    
    /// Helper function to find the outside path from trim results
    private func findOutsidePath(from trimmedPaths: [CGPath], original: CGPath, offset: CGPath) -> CGPath? {
        guard !trimmedPaths.isEmpty else { return nil }
        
        // Get bounds of offset for comparison  
        let offsetBounds = offset.boundingBoxOfPath
        
        // The outside path is typically:
        // 1. The largest path by area
        // 2. The path that contains or is closest to the offset bounds
        var bestPath: CGPath?
        var bestScore: CGFloat = 0
        
        for path in trimmedPaths {
            let pathBounds = path.boundingBoxOfPath
            let pathArea = pathBounds.width * pathBounds.height
            
            // Score based on area and proximity to offset bounds
            let areaScore = pathArea
            let proximityScore = pathBounds.intersection(offsetBounds).width * pathBounds.intersection(offsetBounds).height
            let totalScore = areaScore + proximityScore * 2.0 // Weight proximity higher
            
            if totalScore > bestScore {
                bestScore = totalScore
                bestPath = path
            }
        }
        
        return bestPath ?? trimmedPaths.first
    }
} 