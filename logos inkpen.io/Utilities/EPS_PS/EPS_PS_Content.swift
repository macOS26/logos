//
//  EPSContent.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI
import CoreGraphics

struct EPSContent {
    let shapes: [VectorShape]
    let boundingBox: CGRect
    let colorSpace: String
    let textCount: Int
    let creator: String?
    let version: String?
}

func parseEPSContent(_ url: URL) throws -> EPSContent {
    Log.fileOperation("🔧 Implementing professional EPS/PostScript parser...", level: .info)
    
    guard let data = try? Data(contentsOf: url) else {
        throw VectorImportError.fileNotFound
    }
    
    guard let fileContent = String(data: data, encoding: .utf8) else {
        throw VectorImportError.parsingError("Could not decode EPS file as UTF-8", line: nil)
    }
    
    var shapes: [VectorShape] = []
    var boundingBox = CGRect(x: 0, y: 0, width: 612, height: 792) // Default letter size
    var colorSpace = "RGB"
    var textCount = 0
    var creator: String?
    var version: String?
    
    // Parse EPS header information
    let lines = fileContent.components(separatedBy: .newlines)
    
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Parse bounding box
        if trimmedLine.hasPrefix("%%BoundingBox:") {
            let components = trimmedLine.components(separatedBy: " ")
            if components.count >= 5 {
                if let x = Double(components[1]),
                   let y = Double(components[2]),
                   let width = Double(components[3]),
                   let height = Double(components[4]) {
                    boundingBox = CGRect(x: x, y: y, width: width - x, height: height - y)
                    Log.fileOperation("📋 Found bounding box: \(boundingBox)", level: .info)
                }
            }
        }
        
        // Parse creator
        else if trimmedLine.hasPrefix("%%Creator:") {
            creator = String(trimmedLine.dropFirst("%%Creator:".count)).trimmingCharacters(in: .whitespaces)
        }
        
        // Parse version
        else if trimmedLine.hasPrefix("%%Version:") {
            version = String(trimmedLine.dropFirst("%%Version:".count)).trimmingCharacters(in: .whitespaces)
        }
        
        // Look for color space information
        else if trimmedLine.contains("setcolorspace") || trimmedLine.contains("DeviceRGB") {
            colorSpace = "RGB"
        }
        else if trimmedLine.contains("DeviceCMYK") {
            colorSpace = "CMYK"
        }
        
        // Count text objects (look for text operators)
        else if trimmedLine.contains("show") || trimmedLine.contains("Tj") || trimmedLine.contains("TJ") {
            textCount += 1
        }
    }
    
    // Parse basic PostScript drawing commands to extract shapes
    shapes = try parsePostScriptPaths(fileContent)
    
    Log.info("✅ EPS parsing completed: \(shapes.count) shapes, \(textCount) text objects", category: .fileOperations)
    
    return EPSContent(
        shapes: shapes,
        boundingBox: boundingBox,
        colorSpace: colorSpace,
        textCount: textCount,
        creator: creator,
        version: version
    )
}


func parsePostScriptPaths(_ content: String) throws -> [VectorShape] {
    var shapes: [VectorShape] = []
    var currentPath: [PathElement] = []
    var currentPoint: CGPoint = .zero
    
    let lines = content.components(separatedBy: .newlines)
    
    for line in lines {
        let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
        guard !components.isEmpty else { continue }
        
        let command = components.last?.trimmingCharacters(in: .whitespaces) ?? ""
        
        switch command {
        case "moveto", "m":
            // Move to command
            if components.count >= 3,
               let x = Double(components[0]),
               let y = Double(components[1]) {
                currentPoint = CGPoint(x: x, y: y)
                currentPath.append(.move(to: VectorPoint(currentPoint)))
            }
            
        case "lineto", "l":
            // Line to command
            if components.count >= 3,
               let x = Double(components[0]),
               let y = Double(components[1]) {
                currentPoint = CGPoint(x: x, y: y)
                currentPath.append(.line(to: VectorPoint(currentPoint)))
            }
            
        case "curveto", "c":
            // Cubic bezier curve command
            if components.count >= 7,
               let x1 = Double(components[0]),
               let y1 = Double(components[1]),
               let x2 = Double(components[2]),
               let y2 = Double(components[3]),
               let x3 = Double(components[4]),
               let y3 = Double(components[5]) {
                currentPoint = CGPoint(x: x3, y: y3)
                currentPath.append(.curve(
                    to: VectorPoint(currentPoint),
                    control1: VectorPoint(x1, y1),
                    control2: VectorPoint(x2, y2)
                ))
            }
            
        case "closepath", "z":
            // Close path command
            currentPath.append(.close)
            
        case "stroke", "fill", "stroke\nfill":
            // End of path - create shape
            if !currentPath.isEmpty {
                let vectorPath = VectorPath(elements: currentPath)
                let shape = VectorShape(
                    name: "EPS Shape \(shapes.count + 1)",
                    path: vectorPath,
                    strokeStyle: command.contains("stroke") ? StrokeStyle(color: .black, width: 1.0, placement: .center) : nil,
                    fillStyle: command.contains("fill") ? FillStyle(color: .rgb(RGBColor(red: 0.7, green: 0.7, blue: 0.9))) : nil
                )
                shapes.append(shape)
                currentPath.removeAll()
            }
            
        default:
            // Skip unknown commands
            break
        }
    }
    
    return shapes
}

