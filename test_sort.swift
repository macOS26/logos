#!/usr/bin/env swift

func getWeightOrder(_ variantName: String) -> Int {
    let name = variantName.lowercased()
    let isItalic = name.contains("italic") || name.contains("oblique")

    // Check for compound patterns first (most specific to least specific)
    if name.contains("condensed") && name.contains("black") {
        return isItalic ? 31 : 30
    }
    if name.contains("condensed") && name.contains("bold") {
        return isItalic ? 29 : 28
    }
    if name.contains("extra") && name.contains("black") {
        return isItalic ? 27 : 26
    }
    if name.contains("ultra") && name.contains("black") {
        return isItalic ? 25 : 24
    }
    if name.contains("extra") && name.contains("bold") {
        return isItalic ? 19 : 18
    }
    if name.contains("ultra") && name.contains("light") {
        return isItalic ? 1 : 0
    }
    if name.contains("demi") && name.contains("bold") {
        return isItalic ? 13 : 12
    }
    if name.contains("semi") && name.contains("bold") {
        return isItalic ? 15 : 14
    }

    // Single weight patterns
    if name.contains("black") {
        return isItalic ? 23 : 22
    }
    if name.contains("heavy") {
        return isItalic ? 21 : 20
    }
    if name.contains("bold") {
        return isItalic ? 17 : 16
    }
    if name.contains("medium") {
        return isItalic ? 11 : 10
    }
    if name.contains("book") {
        return isItalic ? 7 : 6
    }
    if name.contains("light") {
        return isItalic ? 5 : 4
    }
    if name.contains("thin") {
        return isItalic ? 3 : 2
    }
    if name.contains("regular") || name.contains("normal") {
        return isItalic ? 9 : 8
    }

    // If only "italic" with no weight, treat as Regular Italic
    if isItalic {
        return 9
    }

    return 1000
}

let variants = [
    "Regular",
    "Italic",
    "UltraLight",
    "UltraLight Italic",
    "Thin",
    "Thin Italic",
    "Light",
    "Light Italic",
    "Medium",
    "Medium Italic",
    "Bold",
    "Bold Italic",
    "Condensed Bold",
    "Condensed Black"
]

print("Variant Order Mapping:")
print(String(repeating: "=", count: 50))

for variant in variants {
    let order = getWeightOrder(variant)
    print("\(order): \(variant)")
}

print("\n")
print("Sorted Order:")
print(String(repeating: "=", count: 50))

let sorted = variants.sorted { lhs, rhs in
    return getWeightOrder(lhs) < getWeightOrder(rhs)
}

for (index, variant) in sorted.enumerated() {
    print("\(index + 1). \(variant)")
}
