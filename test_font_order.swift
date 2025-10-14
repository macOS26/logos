#!/usr/bin/env swift
import AppKit

let fontManager = NSFontManager.shared

// Test with a common font family
let family = "Helvetica Neue"
print("Testing font family: \(family)")
print(String(repeating: "=", count: 50))

if let members = fontManager.availableMembers(ofFontFamily: family) {
    for (index, member) in members.enumerated() {
        if let postScriptName = member[0] as? String,
           let displayName = member[1] as? String,
           let weightNumber = member[2] as? NSNumber,
           let traitsNumber = member[3] as? NSNumber {
            print("\(index): \(displayName)")
            print("   PostScript: \(postScriptName)")
            print("   Weight: \(weightNumber.intValue)")
            print("   Traits: \(traitsNumber.intValue)")
        }
    }
}
