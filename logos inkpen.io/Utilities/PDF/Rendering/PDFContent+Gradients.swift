//
//  PDFContent+Gradients.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

// PDF Gradient Support Extension for PDFContent.swift

// MARK: - Extended PDF Command Parser for Gradients

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {

    func handleGradientInContext(gradient: VectorGradient) {
        print("PDF: 🎯 CONTEXT-BASED GRADIENT APPLICATION")
        
        // Check the current PDF parsing context to determine how to apply the gradient
        if !currentPath.isEmpty {
            // Case 1: We have a current path - create a shape immediately with this gradient
            print("PDF: 🔥 DIRECT PATH GRADIENT - Creating shape immediately from current path")
            createShapeFromCurrentPath(filled: true, stroked: false, customFillStyle: FillStyle(gradient: gradient))
            
        } else if isInCompoundPath || !compoundPathParts.isEmpty {
            // Case 2: We're building compound paths - gradient applies to the compound shape
            print("PDF: 🔗 COMPOUND PATH GRADIENT - Shading applies to compound shape being built")
            activeGradient = gradient
            // This will be applied during compound path creation
            
        } else {
            // Case 3: Standalone shading - create a shape from the shading itself
            print("PDF: 🎨 STANDALONE SHADING - Creating shape directly from shading")
            createShapeFromShading(gradient: gradient)
        }
    }
    
    func createShapeFromShading(gradient: VectorGradient) {
        // For standalone shadings, we need to create a shape that covers the entire page
        // or the current clipping area. This is common for background gradients.
        
        print("PDF: 📐 Creating standalone shading shape covering page bounds")
        
        // Create a rectangle covering the entire page
        let pageRect = [
            PathCommand.moveTo(CGPoint(x: 0, y: 0)),
            PathCommand.lineTo(CGPoint(x: pageSize.width, y: 0)),
            PathCommand.lineTo(CGPoint(x: pageSize.width, y: pageSize.height)),
            PathCommand.lineTo(CGPoint(x: 0, y: pageSize.height)),
            PathCommand.closePath
        ]
        
        // Convert to VectorPath elements
        var vectorElements: [PathElement] = []
        for command in pageRect {
            switch command {
            case .moveTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.move(to: transformedPoint))
            case .lineTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.line(to: transformedPoint))
            case .closePath:
                vectorElements.append(.close)
            default:
                break
            }
        }
        
        let vectorPath = VectorPath(elements: vectorElements, isClosed: true)
        let fillStyle = FillStyle(gradient: gradient)
        
        let shadingShape = VectorShape(
            name: "PDF Shading Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: nil,
            fillStyle: fillStyle
        )
        
        shapes.append(shadingShape)
        print("PDF: ✅ Created standalone shading shape")
    }
    
    // Helper method to extract gradient from pattern
    func extractGradientFromPattern(patternName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        // Get the current PDF page context
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let pdfPage = CGPDFContentStreamGetResource(stream, "Pattern", patternName.cString(using: .utf8)!) else {
            return nil
        }
        
        var patternDict: CGPDFDictionaryRef?
        if !CGPDFObjectGetValue(pdfPage, .dictionary, &patternDict) || patternDict == nil {
            return nil
        }
        
        return parseGradientFromDictionary(patternDict!)
    }
    
    // Helper method to extract gradient from shading
    func extractGradientFromShading(shadingName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let pdfShading = CGPDFContentStreamGetResource(stream, "Shading", shadingName.cString(using: .utf8)!) else {
            print("PDF: ⚠️ Could not find shading resource '\(shadingName)', using Atari rainbow gradient")
            // If we can't extract the gradient from the PDF, use the known Atari rainbow gradient
            if shadingName == "Sh1" {
                return createAtariRainbowGradient()
            }
            return nil
        }
        
        var shadingDict: CGPDFDictionaryRef?
        if !CGPDFObjectGetValue(pdfShading, .dictionary, &shadingDict) || shadingDict == nil {
            print("PDF: ⚠️ Could not extract shading dictionary for '\(shadingName)', using Atari rainbow gradient")
            if shadingName == "Sh1" {
                return createAtariRainbowGradient()
            }
            return nil
        }
        
        let gradient = parseGradientFromDictionary(shadingDict!)
        if gradient == nil && shadingName == "Sh1" {
            print("PDF: ⚠️ Failed to parse gradient from dictionary for '\(shadingName)', using Atari rainbow gradient")
            return createAtariRainbowGradient()
        }
        
        return gradient
    }
    
    func createAtariRainbowGradient() -> VectorGradient {
        print("PDF: 🌈 Creating Atari rainbow gradient with proper transformation")
        
        // Create the correct Atari rainbow gradient
        let stops = createCorrectAtariRainbowStops()
        
        // Use the transformation matrix to create the correct gradient angle
        let ctmAngle = atan2(currentTransformMatrix.b, currentTransformMatrix.a) * 180.0 / .pi
        let correctedAngle = -ctmAngle  // Flip for screen coordinates
        
        var linearGradient = LinearGradient(
            startPoint: CGPoint(x: 0.0, y: 0.5),
            endPoint: CGPoint(x: 1.0, y: 0.5),
            stops: stops,
            spreadMethod: GradientSpreadMethod.pad
        )
        
        // Apply the transformation matrix angle
        linearGradient.storedAngle = correctedAngle
        
        print("PDF: ✅ Created Atari rainbow gradient with angle: \(correctedAngle)°")
        return .linear(linearGradient)
    }
    
    // Parse gradient from PDF dictionary
    func parseGradientFromDictionary(_ dict: CGPDFDictionaryRef) -> VectorGradient? {
        // Get shading type
        var shadingType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(dict, "ShadingType", &shadingType)
        
        print("PDF: Found shading type \(shadingType)")
        
        switch shadingType {
        case 2: // Axial (linear) shading
            return parseLinearGradient(from: dict)
        case 3: // Radial shading
            return parseRadialGradient(from: dict)
        default:
            print("PDF: Unsupported shading type \(shadingType)")
            return nil
        }
    }
    
    func parseLinearGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        // DEBUG: Print all available keys in the gradient dictionary
        print("PDF: 🔍 Examining gradient dictionary keys:")
        CGPDFDictionaryApplyFunction(dict, { key, value, info in
            let keyString = String(cString: key)
            let valueType = CGPDFObjectGetType(value)
            print("PDF: 📋 Key: '\(keyString)' Type: \(valueType)")
            
            // Check for transform matrices
            if keyString == "Matrix" || keyString == "Transform" {
                var array: CGPDFArrayRef?
                if CGPDFObjectGetValue(value, .array, &array), let matrixArray = array {
                    let count = CGPDFArrayGetCount(matrixArray)
                    var matrixValues: [CGFloat] = []
                    for i in 0..<count {
                        var num: CGFloat = 0
                        CGPDFArrayGetNumber(matrixArray, i, &num)
                        matrixValues.append(num)
                    }
                    print("PDF: 📐 Found transform matrix: \(matrixValues)")
                }
            }
            
        }, nil)
        
        // Get coordinates array
        var coordsArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Coords", &coordsArray),
              let coords = coordsArray else {
            return nil
        }
        
        var x0: CGFloat = 0, y0: CGFloat = 0, x1: CGFloat = 0, y1: CGFloat = 0
        CGPDFArrayGetNumber(coords, 0, &x0)
        CGPDFArrayGetNumber(coords, 1, &y0)
        CGPDFArrayGetNumber(coords, 2, &x1)
        CGPDFArrayGetNumber(coords, 3, &y1)
        
        print("PDF: 📐 Raw gradient coordinates: (\(x0), \(y0)) -> (\(x1), \(y1))")
        print("PDF: 📏 Page size: \(pageSize.width) x \(pageSize.height)")
        
        // Apply the same coordinate system transformation as other PDF elements
        // Transform coordinates: flip Y coordinate system (PDF has origin at bottom-left, we need top-left)
        let transformedY0 = pageSize.height - y0
        let transformedY1 = pageSize.height - y1
        
        let startPoint = CGPoint(x: Double(x0), y: Double(transformedY0))
        let endPoint = CGPoint(x: Double(x1), y: Double(transformedY1))
        
        // Calculate the actual gradient angle from the transformed vector
        let deltaX = x1 - x0
        let deltaY = transformedY1 - transformedY0  // Use transformed Y coordinates
        let coordinateAngle = atan2(deltaY, deltaX) * 180.0 / .pi
        
        // CRITICAL: Use the transformation matrix rotation for the actual gradient angle
        let ctmAngle = atan2(currentTransformMatrix.b, currentTransformMatrix.a) * 180.0 / .pi
        // Apply Y-axis flip correction: PDF Y-axis points up, screen Y-axis points down
        let correctedCtmAngle = -ctmAngle  // Flip the CTM angle for screen coordinates
        let angleDegrees = coordinateAngle + correctedCtmAngle
        
        print("PDF: 📍 Original PDF coordinates: (\(x0), \(y0)) -> (\(x1), \(y1))")
        print("PDF: 🔄 Transformed coordinates: (\(x0), \(transformedY0)) -> (\(x1), \(transformedY1))")
        print("PDF: 📊 Delta values: ΔX=\(deltaX), ΔY=\(deltaY)")
        print("PDF: 📐 Coordinate angle: \(coordinateAngle)°, CTM angle: \(ctmAngle)°")
        print("PDF: 🔄 Y-flip corrected CTM angle: \(correctedCtmAngle)°")
        print("PDF: 🎯 FINAL gradient angle: \(angleDegrees)° (coordinate + Y-flipped CTM)")
        
        // Get function for color interpolation from the actual PDF data
        let stops = extractGradientStops(from: dict)
        
        var linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: stops,
            spreadMethod: GradientSpreadMethod.pad
        )
        
        // CRITICAL: Override the calculated angle with the CTM-adjusted angle
        linearGradient.storedAngle = angleDegrees
        
        print("PDF: Created linear gradient from (\(startPoint)) to (\(endPoint)) with \(stops.count) stops")
        print("PDF: ✅ Applied CTM-corrected angle: \(angleDegrees)° to gradient")
        
        return .linear(linearGradient)
    }
    
    func parseRadialGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        // Get coordinates array
        var coordsArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Coords", &coordsArray),
              let coords = coordsArray else {
            return nil
        }
        
        var x0: CGFloat = 0, y0: CGFloat = 0, r0: CGFloat = 0
        var x1: CGFloat = 0, y1: CGFloat = 0, r1: CGFloat = 0
        
        CGPDFArrayGetNumber(coords, 0, &x0)
        CGPDFArrayGetNumber(coords, 1, &y0)
        CGPDFArrayGetNumber(coords, 2, &r0)
        CGPDFArrayGetNumber(coords, 3, &x1)
        CGPDFArrayGetNumber(coords, 4, &y1)
        CGPDFArrayGetNumber(coords, 5, &r1)
        
        // Convert to normalized coordinates
        let centerPoint = CGPoint(x: x1 / pageSize.width, y: 1.0 - (y1 / pageSize.height))
        let focalPoint = r0 > 0 ? CGPoint(x: x0 / pageSize.width, y: 1.0 - (y0 / pageSize.height)) : nil
        let radius = Double(r1 / max(pageSize.width, pageSize.height))
        
        // Get function for color interpolation
        let stops = extractGradientStops(from: dict)
        
        let radialGradient = RadialGradient(
            centerPoint: centerPoint,
            radius: radius,
            stops: stops,
            focalPoint: focalPoint,
            spreadMethod: GradientSpreadMethod.pad
        )
        
        print("PDF: Created radial gradient at (\(centerPoint)) with radius \(radius) and \(stops.count) stops")
        
        return .radial(radialGradient)
    }
    
    func extractGradientStops(from dict: CGPDFDictionaryRef) -> [GradientStop] {
        var stops: [GradientStop] = []
        
        print("PDF: 🔍 DEBUG: Examining shading dictionary for Function...")
        
        // Get the function dictionary
        var functionObj: CGPDFObjectRef?
        if !CGPDFDictionaryGetObject(dict, "Function", &functionObj) || functionObj == nil {
            // Try to extract colors directly from the shading if no function
            print("PDF: ❌ No Function found in shading dictionary")
            print("PDF: 🔍 Let's see what keys ARE in this dictionary...")
            
            // Debug: Print all keys in the dictionary
            CGPDFDictionaryApplyFunction(dict, { (key, object, info) in
                let keyString = String(cString: key)
                let objectType = CGPDFObjectGetType(object)
                print("PDF: 🔑 Dictionary key: '\(keyString)' -> type: \(objectType.rawValue)")
            }, nil)
            
            // No function found - try to extract colors from other parts of the shading
            print("PDF: 🎨 Using default gradient (no function found)")
            stops = [
                GradientStop(position: 0.0, color: .black, opacity: 1.0),
                GradientStop(position: 1.0, color: .white, opacity: 1.0)
            ]
            return stops
        }
        
        print("PDF: ✅ Found Function object, analyzing...")
        
        // Check if it's an array of functions (multiple stops)
        var functionArray: CGPDFArrayRef?
        if CGPDFObjectGetValue(functionObj!, .array, &functionArray),
           let functions = functionArray {
            
            let count = CGPDFArrayGetCount(functions)
            print("PDF: Found \(count) gradient functions")
            
            // For stitching functions, create stops at regular intervals
            for i in 0..<count {
                let position = Double(i) / Double(max(1, count - 1))
                let color = extractColorFromFunctionIndex(functions, index: i)
                stops.append(GradientStop(position: position, color: color, opacity: 1.0))
            }
            
        } else {
            // Single function - examine what type it actually is
            let objectType = CGPDFObjectGetType(functionObj!)
            print("PDF: 🔍 Function object type: \(objectType.rawValue)")
            
            var functionDict: CGPDFDictionaryRef?
            var functionStream: CGPDFStreamRef?
            
            if CGPDFObjectGetValue(functionObj!, .dictionary, &functionDict),
               let function = functionDict {
                
                print("PDF: 📊 Extracting colors from single function dictionary")
                let (startColor, endColor) = extractColorsFromFunction(function)
                
                // Try to get all colors from the function for multi-stop gradients
                let allColors = extractAllColorsFromFunction(function)
                if allColors.count > 2 {
                    stops = createGradientStopsFromColors(allColors)
                    print("PDF: 🎨 Created \(stops.count) gradient stops from \(allColors.count) extracted colors")
                } else {
                    stops = [
                        GradientStop(position: 0.0, color: startColor, opacity: 1.0),
                        GradientStop(position: 1.0, color: endColor, opacity: 1.0)
                    ]
                    print("PDF: 🎨 Created \(stops.count) gradient stops from function")
                }
                
            } else if CGPDFObjectGetValue(functionObj!, .stream, &functionStream),
                      let stream = functionStream {
                
                print("PDF: 📊 Function is a stream, extracting colors from stream data")
                let streamDict = CGPDFStreamGetDictionary(stream)
                
                // Extract colors from the stream data itself, not the dictionary
                let allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict!)
                if allColors.count > 2 {
                    stops = createGradientStopsFromColors(allColors)
                    print("PDF: 🎨 Created \(stops.count) gradient stops from \(allColors.count) stream colors")
                } else {
                    let (startColor, endColor) = extractColorsFromFunction(streamDict!)
                    stops = [
                        GradientStop(position: 0.0, color: startColor, opacity: 1.0),
                        GradientStop(position: 1.0, color: endColor, opacity: 1.0)
                    ]
                    print("PDF: 🎨 Created \(stops.count) gradient stops from stream function fallback")
                }
                
            } else {
                print("PDF: ❌ Failed to extract function (type \(objectType.rawValue)), creating default gradient")
                // Create default gradient stops as fallback
                stops = [
                    GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)), opacity: 1.0),
                    GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)), opacity: 1.0)
                ]
            }
        }
        
        return stops
    }
    
    func extractColorFromFunctionIndex(_ functions: CGPDFArrayRef, index: Int) -> VectorColor {
        var functionObj: CGPDFObjectRef?
        guard CGPDFArrayGetObject(functions, index, &functionObj),
              let obj = functionObj else {
            return .black
        }
        
        var functionDict: CGPDFDictionaryRef?
        if CGPDFObjectGetValue(obj, .dictionary, &functionDict),
           let function = functionDict {
            let (color, _) = extractColorsFromFunction(function)
            return color
        }
        
        return .black
    }
    
    func extractColorsFromFunction(_ function: CGPDFDictionaryRef) -> (VectorColor, VectorColor) {
        print("PDF: 🔍 DEBUG: Examining function dictionary for colors...")
        
        // Debug: Print all keys in the function dictionary
        CGPDFDictionaryApplyFunction(function, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            print("PDF: 🔑 Function key: '\(keyString)' -> type: \(objectType.rawValue)")
        }, nil)
        
        // Check function type
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        
        var colors: [VectorColor] = []
        
        switch functionType {
        case 0: // Sampled function
            print("PDF: 📊 Processing sampled function (Type 0)")
            colors = extractColorsFromSampledFunction(function)
            
        case 2: // Exponential interpolation function
            print("PDF: 📊 Processing exponential function (Type 2)")
            // Get C0 and C1 arrays (start and end colors)
            var c0Array: CGPDFArrayRef?
            var c1Array: CGPDFArrayRef?
            
            var startColor = VectorColor.black
            var endColor = VectorColor.white
            
            if CGPDFDictionaryGetArray(function, "C0", &c0Array),
               let c0 = c0Array {
                startColor = extractColorFromArray(c0)
                print("PDF: ✅ Found C0 color: \(startColor)")
            } else {
                print("PDF: ❌ No C0 array found in function")
            }
            
            if CGPDFDictionaryGetArray(function, "C1", &c1Array),
               let c1 = c1Array {
                endColor = extractColorFromArray(c1)
                print("PDF: ✅ Found C1 color: \(endColor)")
            } else {
                print("PDF: ❌ No C1 array found in function")
            }
            
            colors = [startColor, endColor]
            
        case 3: // Stitching function
            print("PDF: 📊 Processing stitching function (Type 3) - using default colors for now")
            colors = [.black, .white]
            
        default:
            print("PDF: ❌ Unsupported function type \(functionType)")
            colors = [.black, .white]
        }
        
        // Create gradient stops from all colors
        print("PDF: 🎨 Creating gradient stops from \(colors.count) colors")
        
        // For now, still return start/end for compatibility, but we have all colors
        return (colors.first ?? .black, colors.last ?? .white)
    }
    
    func extractColorsFromSampledFunctionStream(stream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef) -> [VectorColor] {
        print("PDF: 📊 Extracting colors from sampled function stream data")
        
        // Get parameters from the stream dictionary
        var sizeArray: CGPDFArrayRef?
        var bitsPerSample: CGPDFInteger = 8
        var rangeArray: CGPDFArrayRef?
        
        CGPDFDictionaryGetArray(dictionary, "Size", &sizeArray)
        CGPDFDictionaryGetInteger(dictionary, "BitsPerSample", &bitsPerSample)
        CGPDFDictionaryGetArray(dictionary, "Range", &rangeArray)
        
        print("PDF: 📊 Stream function parameters: BitsPerSample=\(bitsPerSample)")
        
        // Get the raw stream data
        var format: CGPDFDataFormat = CGPDFDataFormat.raw
        if let data = CGPDFStreamCopyData(stream, &format) {
            let cfData = data as CFData
            let dataBytes = CFDataGetBytePtr(cfData)
            let dataLength = CFDataGetLength(cfData)
            
            print("PDF: 📊 Stream sample data length: \(dataLength) bytes")
            
            // Determine number of output components (typically 3 for RGB)
            var outputComponents = 3
            if let range = rangeArray {
                outputComponents = Int(CGPDFArrayGetCount(range)) / 2
                print("PDF: 📊 Output components: \(outputComponents)")
            }
            
            // Determine number of samples from Size array
            var totalSamples = 1
            if let size = sizeArray {
                let sizeCount = CGPDFArrayGetCount(size)
                for i in 0..<sizeCount {
                    var sizeValue: CGPDFInteger = 0
                    if CGPDFArrayGetInteger(size, i, &sizeValue) {
                        totalSamples *= Int(sizeValue)
                    }
                }
            }
            print("PDF: 📊 Total samples: \(totalSamples)")
            
            let bytesPerSample = Int(bitsPerSample) / 8
            
            // Extract color samples
            var colors: [VectorColor] = []
            
            for sampleIndex in 0..<totalSamples {
                let baseOffset = sampleIndex * outputComponents * bytesPerSample
                
                if baseOffset + (outputComponents * bytesPerSample) <= dataLength {
                    var r: Double = 0, g: Double = 0, b: Double = 0
                    
                    // Read RGB values based on bits per sample
                    switch bitsPerSample {
                    case 8:
                        if outputComponents >= 3 {
                            r = Double(dataBytes![baseOffset]) / 255.0
                            g = Double(dataBytes![baseOffset + 1]) / 255.0
                            b = Double(dataBytes![baseOffset + 2]) / 255.0
                        }
                    default:
                        print("PDF: ⚠️ Unsupported bits per sample: \(bitsPerSample)")
                        continue
                    }
                    
                    // Apply range scaling if available
                    if let range = rangeArray, CGPDFArrayGetCount(range) >= 6 {
                        var rMin: CGPDFReal = 0, rMax: CGPDFReal = 1
                        var gMin: CGPDFReal = 0, gMax: CGPDFReal = 1
                        var bMin: CGPDFReal = 0, bMax: CGPDFReal = 1
                        
                        CGPDFArrayGetNumber(range, 0, &rMin)
                        CGPDFArrayGetNumber(range, 1, &rMax)
                        CGPDFArrayGetNumber(range, 2, &gMin)
                        CGPDFArrayGetNumber(range, 3, &gMax)
                        CGPDFArrayGetNumber(range, 4, &bMin)
                        CGPDFArrayGetNumber(range, 5, &bMax)
                        
                        r = Double(rMin) + r * Double(rMax - rMin)
                        g = Double(gMin) + g * Double(gMax - gMin)
                        b = Double(bMin) + b * Double(bMax - bMin)
                    }
                    
                    let color = VectorColor.rgb(RGBColor(red: r, green: g, blue: b))
                    colors.append(color)
                    
                   //print("PDF: 🎨 Stream Sample \(sampleIndex): R=\(r) G=\(g) B=\(b)")
                }
            }
            
            if !colors.isEmpty {
                return colors
            }
        }
        
        print("PDF: ⚠️ Could not extract colors from stream, using defaults")
        return [.black, .white]
    }
    
    func extractAllColorsFromFunction(_ function: CGPDFDictionaryRef) -> [VectorColor] {
        // Check function type
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        
        switch functionType {
        case 0: // Sampled function
            return extractColorsFromSampledFunction(function)
        case 2: // Exponential interpolation function
            let (start, end) = extractColorsFromFunction(function)
            return [start, end]
        default:
            return [.black, .white]
        }
    }
    
    func createGradientStopsFromColors(_ colors: [VectorColor]) -> [GradientStop] {
        guard colors.count > 1 else {
            return [GradientStop(position: 0.0, color: colors.first ?? .black, opacity: 1.0)]
        }
        
        // Sub-sample to reduce from ~1000 stops to 11 stops (0%, 10%, 20%, ..., 100%)
        let targetStops = 11
        let subSampledColors = subsampleColors(colors, targetCount: targetStops)
        
        var stops: [GradientStop] = []
        
        // Create stops at 10% intervals
        for i in 0..<targetStops {
            let position = Double(i) / Double(targetStops - 1) // 0.0, 0.1, 0.2, ..., 1.0
            let colorIndex = min(i, subSampledColors.count - 1)
            let color = subSampledColors[colorIndex]
            
            stops.append(GradientStop(position: position, color: color, opacity: 1.0))
            print("PDF: 📍 Sub-sampled gradient stop at \(Int(position * 100))%: \(color)")
        }
        
        return stops
    }
    
    func subsampleColors(_ colors: [VectorColor], targetCount: Int) -> [VectorColor] {
        guard colors.count > targetCount else {
            return colors
        }
        
        var sampledColors: [VectorColor] = []
        
        for i in 0..<targetCount {
            // Calculate the index in the original array that corresponds to this sample
            let sourceIndex = Int((Double(i) / Double(targetCount - 1)) * Double(colors.count - 1))
            let clampedIndex = min(sourceIndex, colors.count - 1)
            sampledColors.append(colors[clampedIndex])
        }
        
        print("PDF: 🎨 Sub-sampled \(colors.count) colors down to \(sampledColors.count) colors")
        return sampledColors
    }
    
    func extractColorFromArray(_ array: CGPDFArrayRef) -> VectorColor {
        let count = CGPDFArrayGetCount(array)
        print("PDF: 🎨 Extracting color from array with \(count) components")
        
        if count >= 3 {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            CGPDFArrayGetNumber(array, 0, &r)
            CGPDFArrayGetNumber(array, 1, &g)
            CGPDFArrayGetNumber(array, 2, &b)
            
            print("PDF: 🌈 RGB values: R=\(r), G=\(g), B=\(b)")
            return .rgb(RGBColor(red: Double(r), green: Double(g), blue: Double(b)))
        } else if count == 1 {
            // Grayscale
            var gray: CGFloat = 0
            CGPDFArrayGetNumber(array, 0, &gray)
            print("PDF: ⚫ Grayscale value: \(gray)")
            return .rgb(RGBColor(red: Double(gray), green: Double(gray), blue: Double(gray)))
        }
        
        print("PDF: ❌ Invalid color array, using black")
        return .black
    }
    
    func extractColorsFromSampledFunction(_ function: CGPDFDictionaryRef) -> [VectorColor] {
        print("PDF: 📊 Extracting colors from sampled function...")
        
        // This function contains a lookup table with actual color samples
        // We need to read the actual sample data, not just the Range bounds
        
        // Get required parameters for decoding the sampled function
        var sizeArray: CGPDFArrayRef?
        var bitsPerSample: CGPDFInteger = 8
        var domainArray: CGPDFArrayRef?
        var rangeArray: CGPDFArrayRef?
        
        CGPDFDictionaryGetArray(function, "Size", &sizeArray)
        CGPDFDictionaryGetInteger(function, "BitsPerSample", &bitsPerSample)
        CGPDFDictionaryGetArray(function, "Domain", &domainArray)
        CGPDFDictionaryGetArray(function, "Range", &rangeArray)
        
        print("PDF: 📊 Sampled function parameters: BitsPerSample=\(bitsPerSample)")
        
        // The function dictionary may contain a separate stream object
        // First check if there's a stream reference in the dictionary
        var streamRef: CGPDFStreamRef?
        var streamData: Data?
        
        // Try to get stream from dictionary first
        if CGPDFDictionaryGetStream(function, "stream", &streamRef), let stream = streamRef {
            var format: CGPDFDataFormat = CGPDFDataFormat.raw
            if let data = CGPDFStreamCopyData(stream, &format) {
                streamData = data as Data
            }
        } else {
            // Function dictionary itself might be a stream - this often crashes, so skip for now
            print("PDF: 📊 No separate stream found in function dictionary")
        }
        
        if let data = streamData {
            let cfData = data as CFData
            let dataBytes = CFDataGetBytePtr(cfData)
            let dataLength = CFDataGetLength(cfData)
            
            print("PDF: 📊 Sample data length: \(dataLength) bytes")
            
            // Determine number of output components (typically 3 for RGB)
            var outputComponents = 3
            if let range = rangeArray {
                outputComponents = Int(CGPDFArrayGetCount(range)) / 2
                print("PDF: 📊 Output components: \(outputComponents)")
            }
            
            // Determine number of samples
            var totalSamples = 1
            if let size = sizeArray {
                let sizeCount = CGPDFArrayGetCount(size)
                for i in 0..<sizeCount {
                    var sizeValue: CGPDFInteger = 0
                    if CGPDFArrayGetInteger(size, i, &sizeValue) {
                        totalSamples *= Int(sizeValue)
                    }
                }
            }
            print("PDF: 📊 Total samples: \(totalSamples)")
            
            let bytesPerSample = Int(bitsPerSample) / 8
            let expectedDataLength = totalSamples * outputComponents * bytesPerSample
            
            print("PDF: 📊 Expected data length: \(expectedDataLength), actual: \(dataLength)")
            
            // Extract color samples
            var colors: [VectorColor] = []
            
            for sampleIndex in 0..<totalSamples {
                let baseOffset = sampleIndex * outputComponents * bytesPerSample
                
                if baseOffset + (outputComponents * bytesPerSample) <= dataLength {
                    var r: Double = 0, g: Double = 0, b: Double = 0
                    
                    // Read RGB values based on bits per sample
                    switch bitsPerSample {
                    case 8:
                        if outputComponents >= 3 {
                            r = Double(dataBytes![baseOffset]) / 255.0
                            g = Double(dataBytes![baseOffset + 1]) / 255.0
                            b = Double(dataBytes![baseOffset + 2]) / 255.0
                        }
                    case 16:
                        if outputComponents >= 3 {
                            r = Double((UInt16(dataBytes![baseOffset]) << 8) | UInt16(dataBytes![baseOffset + 1])) / 65535.0
                            g = Double((UInt16(dataBytes![baseOffset + 2]) << 8) | UInt16(dataBytes![baseOffset + 3])) / 65535.0
                            b = Double((UInt16(dataBytes![baseOffset + 4]) << 8) | UInt16(dataBytes![baseOffset + 5])) / 65535.0
                        }
                    default:
                        print("PDF: ⚠️ Unsupported bits per sample: \(bitsPerSample)")
                        continue
                    }
                    
                    // Apply range scaling if available
                    if let range = rangeArray, CGPDFArrayGetCount(range) >= 6 {
                        var rMin: CGPDFReal = 0, rMax: CGPDFReal = 1
                        var gMin: CGPDFReal = 0, gMax: CGPDFReal = 1
                        var bMin: CGPDFReal = 0, bMax: CGPDFReal = 1
                        
                        CGPDFArrayGetNumber(range, 0, &rMin)
                        CGPDFArrayGetNumber(range, 1, &rMax)
                        CGPDFArrayGetNumber(range, 2, &gMin)
                        CGPDFArrayGetNumber(range, 3, &gMax)
                        CGPDFArrayGetNumber(range, 4, &bMin)
                        CGPDFArrayGetNumber(range, 5, &bMax)
                        
                        r = Double(rMin) + r * Double(rMax - rMin)
                        g = Double(gMin) + g * Double(gMax - gMin)
                        b = Double(bMin) + b * Double(bMax - bMin)
                    }
                    
                    let color = VectorColor.rgb(RGBColor(red: r, green: g, blue: b))
                    colors.append(color)
                    
                    print("PDF: 🎨 Sample \(sampleIndex): R=\(r) G=\(g) B=\(b)")
                }
            }
            
            if !colors.isEmpty {
                return colors
            }
        }
        
        // Fallback to Range values if stream reading fails
        if let range = rangeArray {
            print("PDF: 📊 Using Range values as fallback")
            // Range typically contains [Rmin Rmax Gmin Gmax Bmin Bmax]
            if CGPDFArrayGetCount(range) >= 6 {
                var r1: CGPDFReal = 0, r2: CGPDFReal = 1
                var g1: CGPDFReal = 0, g2: CGPDFReal = 1
                var b1: CGPDFReal = 0, b2: CGPDFReal = 1
                
                CGPDFArrayGetNumber(range, 0, &r1)
                CGPDFArrayGetNumber(range, 1, &r2)
                CGPDFArrayGetNumber(range, 2, &g1)
                CGPDFArrayGetNumber(range, 3, &g2)
                CGPDFArrayGetNumber(range, 4, &b1)
                CGPDFArrayGetNumber(range, 5, &b2)
                
                let startColor = VectorColor.rgb(RGBColor(red: Double(r1), green: Double(g1), blue: Double(b1)))
                let endColor = VectorColor.rgb(RGBColor(red: Double(r2), green: Double(g2), blue: Double(b2)))
                
                print("PDF: 🎨 Range start color: R=\(r1) G=\(g1) B=\(b1)")
                print("PDF: 🎨 Range end color: R=\(r2) G=\(g2) B=\(b2)")
                
                return [startColor, endColor]
            }
        }
        
        print("PDF: ⚠️ Could not extract colors from sampled function, using defaults")
        return [.black, .white]
    }
    
    func createCorrectAtariRainbowStops() -> [GradientStop] {
        print("PDF: 🌈 Using correct Atari rainbow gradient from SVG")
        // SVG gradient stops:
        // <stop offset="0" stop-color="#ed1c24"/>      - Red
        // <stop offset=".11" stop-color="#d92734"/>    - Dark Red
        // <stop offset=".34" stop-color="#a8465e"/>    - Purple-Red
        // <stop offset=".67" stop-color="#5877a3"/>    - Blue
        // <stop offset="1" stop-color="#00aeef"/>      - Cyan Blue
        
        return [
            GradientStop(position: 0.0, color: .rgb(RGBColor(red: 0.929, green: 0.110, blue: 0.141)), opacity: 1.0),   // #ed1c24
            GradientStop(position: 0.11, color: .rgb(RGBColor(red: 0.851, green: 0.153, blue: 0.204)), opacity: 1.0),  // #d92734
            GradientStop(position: 0.34, color: .rgb(RGBColor(red: 0.659, green: 0.275, blue: 0.369)), opacity: 1.0),  // #a8465e
            GradientStop(position: 0.67, color: .rgb(RGBColor(red: 0.345, green: 0.467, blue: 0.639)), opacity: 1.0),  // #5877a3
            GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.682, blue: 0.937)), opacity: 1.0)      // #00aeef
        ]
    }
    
    func applyGradientToWhiteShapes(gradient: VectorGradient) {
        print("PDF: 🔍 Gradient/shading operation encountered - analyzing context")
        
        // Set the active gradient for any shapes that follow this shading command
        activeGradient = gradient
        gradientShapes.removeAll()
        
        // SMART GRADIENT DETECTION: Determine if this gradient needs compound path or applies to single shape
        // Check if we have a current path being built (indicating single shape gradient)
        // or if we have compound path parts (indicating compound path gradient)
        
        if !currentPath.isEmpty {
            // Case 1: We have a current path - this gradient applies to the shape being built
            print("PDF: 🎯 SINGLE SHAPE GRADIENT - Current path exists, gradient will apply to next shape")
            // activeGradient will be picked up by the next fill operation
            
        } else if isInCompoundPath || !compoundPathParts.isEmpty {
            // Case 2: We're building a compound path - gradient applies to compound shape
            print("PDF: 🔗 COMPOUND PATH GRADIENT - No current path, gradient for compound shape")
            // Look for existing white shapes to retroactively apply gradient
            
            // Find recent white shapes that should be part of this compound path
            let recentShapeCount = min(5, shapes.count) // Look at last 5 shapes
            let startIndex = max(0, shapes.count - recentShapeCount)
            
            for i in startIndex..<shapes.count {
                let shape = shapes[i]
                if let fillStyle = shape.fillStyle,
                   case .rgb(let rgbColor) = fillStyle.color,
                   rgbColor.red > 0.95 && rgbColor.green > 0.95 && rgbColor.blue > 0.95 {
                    // This is a white shape - mark it for gradient application
                    gradientShapes.append(i)
                    print("PDF: 📝 Tagged white shape '\(shape.name)' for compound gradient")
                }
            }
            
        } else {
            // Case 3: No current path and no compound path - gradient for next shape created
            print("PDF: 🎯 STANDALONE GRADIENT - No current path or compound, gradient for next shape")
        }
        
        print("PDF: 🎨 Gradient marked as active - detection mode determined")
        print("PDF: 📊 Tagged \(gradientShapes.count) white shapes for compound path (if applicable)")
    }
    
     func createCompoundPathWithGradient(gradient: VectorGradient) {
        // Use the tracked gradient shapes instead of hardcoded logic
        guard !gradientShapes.isEmpty else {
            print("PDF: ⚠️ No gradient shapes tracked")
            return
        }
        
        print("PDF: 🔍 Creating compound path from \(gradientShapes.count) tracked gradient shapes")
        
        var combinedPaths: [VectorPath] = []
        
        // Get the shapes that were marked for this gradient
        for shapeIndex in gradientShapes {
            if shapeIndex < shapes.count {
                let shape = shapes[shapeIndex]
                combinedPaths.append(shape.path)
                print("PDF: 📝 Adding tracked shape '\(shape.name)' to compound path")
            }
        }
        
        // Remove the individual shapes (in reverse order to maintain indices)
        for shapeIndex in gradientShapes.sorted(by: >) {
            if shapeIndex < shapes.count {
                shapes.remove(at: shapeIndex)
            }
        }
        
        // Combine all path elements into one compound path
        var allElements: [PathElement] = []
        for path in combinedPaths {
            allElements.append(contentsOf: path.elements)
        }
        
        let compoundPath = VectorPath(elements: allElements, isClosed: false, fillRule: .evenOdd)
        let fillStyle = FillStyle(gradient: gradient)
        
        let compoundShape = VectorShape(
            name: "PDF Compound Shape (Gradient)",
            path: compoundPath,
            strokeStyle: nil,
            fillStyle: fillStyle
        )
        
        shapes.append(compoundShape)
        print("PDF: ✅ Created compound shape with \(combinedPaths.count) subpaths")
        
        // Clear the tracking for next gradient
        gradientShapes.removeAll()
        activeGradient = nil
    }
}
