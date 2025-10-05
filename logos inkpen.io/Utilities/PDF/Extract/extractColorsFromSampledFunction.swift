//
//  extractColorsFromSampledFunction.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func extractColorsFromSampledFunction(_ function: CGPDFDictionaryRef) -> [VectorColor] {
        Log.info("PDF: 📊 Extracting colors from sampled function...", category: .debug)
        
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
        
        Log.info("PDF: 📊 Sampled function parameters: BitsPerSample=\(bitsPerSample)", category: .debug)
        
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
            Log.info("PDF: 📊 No separate stream found in function dictionary", category: .debug)
        }
        
        if let data = streamData {
            let cfData = data as CFData
            let dataBytes = CFDataGetBytePtr(cfData)
            let dataLength = CFDataGetLength(cfData)
            
            Log.info("PDF: 📊 Sample data length: \(dataLength) bytes", category: .debug)
            
            // Determine number of output components (typically 3 for RGB)
            var outputComponents = 3
            if let range = rangeArray {
                outputComponents = Int(CGPDFArrayGetCount(range)) / 2
                Log.info("PDF: 📊 Output components: \(outputComponents)", category: .debug)
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
            Log.info("PDF: 📊 Total samples: \(totalSamples)", category: .debug)
            
            let bytesPerSample = Int(bitsPerSample) / 8
            let expectedDataLength = totalSamples * outputComponents * bytesPerSample
            
            Log.info("PDF: 📊 Expected data length: \(expectedDataLength), actual: \(dataLength)", category: .debug)
            
            // Extract color samples
            var colors: [VectorColor] = []
            
            for sampleIndex in 0..<totalSamples {
                let baseOffset = sampleIndex * outputComponents * bytesPerSample
                
                if baseOffset + (outputComponents * bytesPerSample) <= dataLength {
                    var r: Double = 0, g: Double = 0, b: Double = 0
                    
                    // Read RGB values based on bits per sample
                    switch bitsPerSample {
                    case 8:
                        if outputComponents >= 3, let bytes = dataBytes {
                            r = Double(bytes[baseOffset]) / 255.0
                            g = Double(bytes[baseOffset + 1]) / 255.0
                            b = Double(bytes[baseOffset + 2]) / 255.0
                        }
                    case 16:
                        if outputComponents >= 3, let bytes = dataBytes {
                            r = Double((UInt16(bytes[baseOffset]) << 8) | UInt16(bytes[baseOffset + 1])) / 65535.0
                            g = Double((UInt16(bytes[baseOffset + 2]) << 8) | UInt16(bytes[baseOffset + 3])) / 65535.0
                            b = Double((UInt16(bytes[baseOffset + 4]) << 8) | UInt16(bytes[baseOffset + 5])) / 65535.0
                        }
                    default:
                        Log.warning("PDF: ⚠️ Unsupported bits per sample: \(bitsPerSample)", category: .general)
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
                    
                    Log.info("PDF: 🎨 Sample \(sampleIndex): R=\(r) G=\(g) B=\(b)", category: .general)
                }
            }
            
            if !colors.isEmpty {
                return colors
            }
        }
        
        // Fallback to Range values if stream reading fails
        if let range = rangeArray {
            Log.info("PDF: 📊 Using Range values as fallback", category: .debug)
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
                
                Log.info("PDF: 🎨 Range start color: R=\(r1) G=\(g1) B=\(b1)", category: .general)
                Log.info("PDF: 🎨 Range end color: R=\(r2) G=\(g2) B=\(b2)", category: .general)
                
                return [startColor, endColor]
            }
        }
        
        Log.warning("PDF: ⚠️ Could not extract colors from sampled function, using defaults", category: .general)
        return [.black, .white]
    }
}
