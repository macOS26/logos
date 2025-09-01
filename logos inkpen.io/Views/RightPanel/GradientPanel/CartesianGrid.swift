//
//  CartesianGrid.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//

import SwiftUI

// MARK: - Cartesian Grid for Gradient Preview

struct CartesianGrid: View {
    let width: CGFloat
    let height: CGFloat
    let onCoordinateClick: ((Double, Double) -> Void)?
    
    init(width: CGFloat, height: CGFloat, onCoordinateClick: ((Double, Double) -> Void)? = nil) {
        self.width = width
        self.height = height
        self.onCoordinateClick = onCoordinateClick
    }
    
    var body: some View {
        ZStack {
            // Vertical grid lines (X-axis markers) - edge to edge
            ForEach(0..<5) { index in
                let position = CGFloat(index) / 4.0  // 0.0 to 1.0
                let xPosition = position * width
                
                // Full-height vertical line (edge to edge)
                Rectangle()
                    .fill(Color.white.opacity(position == 0.5 ? 0.9 : 0.3))
                    .frame(width: position == 0.5 ? 1 : 0.5, height: height)
                    .position(x: xPosition, y: height / 2)
            }
            
            // Horizontal grid lines (Y-axis markers) - edge to edge
            ForEach(0..<5) { index in
                let position = CGFloat(index) / 4.0  // 0.0 to 1.0
                let yPosition = position * height
                
                // Full-width horizontal line (edge to edge)
                Rectangle()
                    .fill(Color.white.opacity(position == 0.5 ? 0.9 : 0.3))
                    .frame(width: width, height: position == 0.5 ? 1 : 0.5)
                    .position(x: width / 2, y: yPosition)
            }
            
            // Coordinate labels at key positions
            VStack {
                HStack {
                    Text("(0,0)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(x: 2, y: 2)
                    Spacer()
                    Text("(0.5,0)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(y: 2)
                    Spacer()
                    Text("(1,0)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(x: -2, y: 2)
                }
                .padding(.horizontal, 4)
                Spacer()
                HStack {
                    Text("(0,1)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(x: 2, y: -2)
                    Spacer()
                    Text("(0.5,1)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(y: -2)
                    Spacer()
                    Text("(1,1)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(x: -2, y: -2)
                }
                .padding(.horizontal, 4)
            }
            
            // Clickable coordinate points
            if let onCoordinateClick = onCoordinateClick {
                // Corner points
                // Top-left (0,0)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: 0)
                    .onTapGesture {
                        onCoordinateClick(0.0, 0.0)
                    }
                
                // Top-right (1,0)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width, y: 0)
                    .onTapGesture {
                        onCoordinateClick(1.0, 0.0)
                    }
                
                // Bottom-left (0,1)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: height)
                    .onTapGesture {
                        onCoordinateClick(0.0, 1.0)
                    }
                
                // Bottom-right (1,1)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width, y: height)
                    .onTapGesture {
                        onCoordinateClick(1.0, 1.0)
                    }
                
                // Center (0.5,0.5)
                Circle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width/2, y: height/2)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.5)
                    }
                
                // Edge midpoints
                // Top center (0.5,0)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width/2, y: 0)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.0)
                    }
                
                // Bottom center (0.5,1)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width/2, y: height)
                    .onTapGesture {
                        onCoordinateClick(0.5, 1.0)
                    }
                
                // Left center (0,0.5)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: height/2)
                    .onTapGesture {
                        onCoordinateClick(0.0, 0.5)
                    }
                
                // Right center (1,0.5)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width, y: height/2)
                    .onTapGesture {
                        onCoordinateClick(1.0, 0.5)
                    }
                
                // Grid intersections (8 additional points)
                // Top-left quadrant center (0.25,0.25)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.25, y: height * 0.25)
                    .onTapGesture {
                        onCoordinateClick(0.25, 0.25)
                    }
                
                // Top-right quadrant center (0.75,0.25)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.75, y: height * 0.25)
                    .onTapGesture {
                        onCoordinateClick(0.75, 0.25)
                    }
                
                // Bottom-left quadrant center (0.25,0.75)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.25, y: height * 0.75)
                    .onTapGesture {
                        onCoordinateClick(0.25, 0.75)
                    }
                
                // Bottom-right quadrant center (0.75,0.75)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.75, y: height * 0.75)
                    .onTapGesture {
                        onCoordinateClick(0.75, 0.75)
                    }
                
                // Left middle (0.25,0.5)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.25, y: height * 0.5)
                    .onTapGesture {
                        onCoordinateClick(0.25, 0.5)
                    }
                
                // Right middle (0.75,0.5)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.75, y: height * 0.5)
                    .onTapGesture {
                        onCoordinateClick(0.75, 0.5)
                    }
                
                // Top middle (0.5,0.25)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.5, y: height * 0.25)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.25)
                    }
                
                // Bottom middle (0.5,0.75)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.5, y: height * 0.75)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.75)
                    }
            }
        }
    }
}