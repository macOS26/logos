//
//  extractColorsFromSampledFunctionStream.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func extractColorsFromSampledFunctionStream(stream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef) -> [VectorColor] {
        Log.info("PDF: 📊 Extracting colors from sampled function stream data", category: .debug)
        
        // Get parameters from the stream dictionary
        var sizeArray: CGPDFArrayRef?
        var bitsPerSample: CGPDFInteger = 8
        var rangeArray: CGPDFArrayRef?
        
        CGPDFDictionaryGetArray(dictionary, "Size", &sizeArray)
        CGPDFDictionaryGetInteger(dictionary, "BitsPerSample", &bitsPerSample)
        CGPDFDictionaryGetArray(dictionary, "Range", &rangeArray)
        
        Log.info("PDF: 📊 Stream function parameters: BitsPerSample=\(bitsPerSample)", category: .debug)
        
        // Get the raw stream data
        var format: CGPDFDataFormat = CGPDFDataFormat.raw
        if let data = CGPDFStreamCopyData(stream, &format) {
            let cfData = data as CFData
            let dataBytes = CFDataGetBytePtr(cfData)
            let dataLength = CFDataGetLength(cfData)
            
            Log.info("PDF: 📊 Stream sample data length: \(dataLength) bytes", category: .debug)
            
            // Determine number of output components (typically 3 for RGB)
            var outputComponents = 3
            if let range = rangeArray {
                outputComponents = Int(CGPDFArrayGetCount(range)) / 2
                Log.info("PDF: 📊 Output components: \(outputComponents)", category: .debug)
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
            Log.info("PDF: 📊 Total samples: \(totalSamples)", category: .debug)
            
            let bytesPerSample = Int(bitsPerSample) / 8

            // Try GPU acceleration for 8-bit samples (most common case)
            if bitsPerSample == 8 && outputComponents >= 3 {
                // Prepare range values for GPU
                var rMin: CGPDFReal = 0, rMax: CGPDFReal = 1
                var gMin: CGPDFReal = 0, gMax: CGPDFReal = 1
                var bMin: CGPDFReal = 0, bMax: CGPDFReal = 1

                if let range = rangeArray, CGPDFArrayGetCount(range) >= 6 {
                    CGPDFArrayGetNumber(range, 0, &rMin)
                    CGPDFArrayGetNumber(range, 1, &rMax)
                    CGPDFArrayGetNumber(range, 2, &gMin)
                    CGPDFArrayGetNumber(range, 3, &gMax)
                    CGPDFArrayGetNumber(range, 4, &bMin)
                    CGPDFArrayGetNumber(range, 5, &bMax)
                }

                let rangeMin: [Float] = [Float(rMin), Float(gMin), Float(bMin)]
                let rangeMax: [Float] = [Float(rMax), Float(gMax), Float(bMax)]

                // Try GPU acceleration
                if let gpuColors = PDFMetalProcessor.shared.extractGradientColors(
                    sampleData: cfData as Data,
                    totalSamples: totalSamples,
                    outputComponents: outputComponents,
                    rangeMin: rangeMin,
                    rangeMax: rangeMax
                ) {
                    Log.info("✅ GPU: Extracted \(gpuColors.count) gradient colors", category: .debug)
                    return gpuColors
                }
            }

            // GPU failed or unavailable - fall back to CPU
            Log.warning("⚠️ Using CPU fallback for gradient color extraction", category: .general)

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
                }
            }

            if !colors.isEmpty {
                return colors
            }
        }
        
        Log.warning("PDF: ⚠️ Could not extract colors from stream, using defaults", category: .general)
        return [.black, .white]
    }
}
