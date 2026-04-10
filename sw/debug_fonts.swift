#!/usr/bin/env swift
import Foundation
import AppKit

let fontManager = NSFontManager.shared
let family = "Helvetica Neue"
let members = fontManager.availableMembers(ofFontFamily: family) ?? []
let excludeKeywords = ["ornament", "swash", "alternate", "expert", "small cap",
                       "oldstyle", "lining", "tabular", "proportional"]

var variants: [(name: String, weight: Int, traits: Int, originalIndex: Int)] = []
var seenNames = Set<String>()

for (index, member) in members.enumerated() {
    if let postScriptName = member[0] as? String,
       let displayName = member[1] as? String,
       let weightNumber = member[2] as? NSNumber,
       let traitsNumber = member[3] as? NSNumber {
        let lowercasedName = displayName.lowercased()
        let shouldExclude = excludeKeywords.contains { keyword in
            lowercasedName.contains(keyword)
        }

        if !shouldExclude, !seenNames.contains(displayName), NSFont(name: postScriptName, size: 12) != nil {
            variants.append((
                name: displayName,
                weight: weightNumber.intValue,
                traits: traitsNumber.intValue,
                originalIndex: index
            ))
            seenNames.insert(displayName)
        }
    }
}

let sortedVariants = variants.sorted { lhs, rhs in
    if lhs.weight != rhs.weight {
        return lhs.weight < rhs.weight
    } else if lhs.traits != rhs.traits {
        return lhs.traits < rhs.traits
    } else {
        return lhs.originalIndex < rhs.originalIndex
    }
}

print("=== NEW SORTING LOGIC (weight, then traits, then original index) ===")
for (index, variant) in sortedVariants.enumerated() {
    print("[\(index)] \(variant.name) (weight: \(variant.weight), traits: \(variant.traits))")
}
