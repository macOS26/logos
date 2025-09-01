//
//  extractColorsFromSampledFunctionStream.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    
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
}