#!/usr/bin/env swift
import AppKit

let fontManager = NSFontManager.shared
let allFonts = fontManager.availableFontFamilies.sorted()

print("Total fonts available: \(allFonts.count)")
print(String(repeating: "=", count: 80))

var problematicFonts: [String] = []
var workingFonts: [String] = []

for fontFamily in allFonts {
    // Test if font can be created
    if let members = fontManager.availableMembers(ofFontFamily: fontFamily),
       !members.isEmpty {

        // Try to get the first variant
        if let firstMember = members.first,
           let postScriptName = firstMember[0] as? String,
           let displayName = firstMember[1] as? String {

            // Try to create a font with this
            if let testFont = NSFont(name: postScriptName, size: 12) {
                // Check if it actually returns the font we asked for
                let actualFontName = testFont.familyName ?? ""

                if actualFontName == fontFamily {
                    workingFonts.append(fontFamily)
                } else {
                    problematicFonts.append("\(fontFamily) -> defaults to \(actualFontName)")
                }
            } else {
                problematicFonts.append("\(fontFamily) -> cannot create font")
            }
        } else {
            problematicFonts.append("\(fontFamily) -> no valid members")
        }
    } else {
        problematicFonts.append("\(fontFamily) -> no members")
    }
}

print("\nPROBLEMATIC FONTS (\(problematicFonts.count)):")
print(String(repeating: "-", count: 80))
for font in problematicFonts {
    print("  ❌ \(font)")
}

print("\n\nWORKING FONTS (\(workingFonts.count)):")
print(String(repeating: "-", count: 80))
for font in workingFonts {
    print("  ✅ \(font)")
}

// Analyze patterns in problematic fonts
print("\n\nPATTERN ANALYSIS:")
print(String(repeating: "-", count: 80))

var prefixCounts: [String: Int] = [:]
for problemFont in problematicFonts {
    let fontName = problemFont.components(separatedBy: " -> ").first ?? ""

    // Check common prefixes
    let prefixes = ["Noto ", ".Apple", "Apple ", ".", "Al ", "Geeza ", "Myanmar "]
    for prefix in prefixes {
        if fontName.hasPrefix(prefix) {
            prefixCounts[prefix, default: 0] += 1
        }
    }
}

print("Problematic font prefixes:")
for (prefix, count) in prefixCounts.sorted(by: { $0.value > $1.value }) {
    print("  '\(prefix)': \(count) fonts")
}
