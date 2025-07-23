//
//  FontPickerView.swift
//  Test
//
//  Created by Todd Bruss on 7/21/25.
//

import SwiftUI
import AppKit

struct FontPickerView: View {
    @Binding var selectedFont: NSFont
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var fontFamilies: [String] = []
    
    var filteredFonts: [String] {
        if searchText.isEmpty {
            return fontFamilies
        } else {
            return fontFamilies.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search fonts...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                // Font list
                List(filteredFonts, id: \.self) { fontFamily in
                    FontRowView(
                        fontFamily: fontFamily,
                        isSelected: fontFamily == selectedFont.familyName,
                        currentSize: selectedFont.pointSize
                    ) {
                        // Try multiple font name variations to ensure we get a valid font
                        var newFont: NSFont?
                        
                        // Try exact family name first
                        newFont = NSFont(name: fontFamily, size: selectedFont.pointSize)
                        
                        // Try common variations
                        if newFont == nil {
                            newFont = NSFont(name: "\(fontFamily)-Regular", size: selectedFont.pointSize)
                        }
                        if newFont == nil {
                            newFont = NSFont(name: "\(fontFamily)-Normal", size: selectedFont.pointSize)
                        }
                        if newFont == nil {
                            newFont = NSFont(name: "\(fontFamily) Regular", size: selectedFont.pointSize)
                        }
                        
                        // Use font manager as fallback
                        if newFont == nil {
                            newFont = NSFontManager.shared.font(withFamily: fontFamily, traits: [], weight: 5, size: selectedFont.pointSize)
                        }
                        
                        // Final fallback to system font with the family name if available
                        if newFont == nil {
                            newFont = NSFont.systemFont(ofSize: selectedFont.pointSize)
                        }
                        
                        if let validFont = newFont {
                            selectedFont = validFont
                        }
                        
                        dismiss()
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Font")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadFontFamilies()
        }
    }
    
    private func loadFontFamilies() {
        fontFamilies = NSFontManager.shared.availableFontFamilies.sorted()
    }
}

struct FontRowView: View {
    let fontFamily: String
    let isSelected: Bool
    let currentSize: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fontFamily)
                    .font(.headline)
                
                Text("The quick brown fox jumps over the lazy dog")
                    .font(Font(sampleFont))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private var sampleFont: NSFont {
        if let font = NSFont(name: fontFamily, size: 14) {
            return font
        } else if let font = NSFont(name: "\(fontFamily)-Regular", size: 14) ??
                    NSFont(name: "\(fontFamily)-Normal", size: 14) ??
                    NSFontManager.shared.font(withFamily: fontFamily, traits: [], weight: 5, size: 14) {
            return font
        } else {
            return NSFont.systemFont(ofSize: 14)
        }
    }
}

#Preview {
    FontPickerView(selectedFont: .constant(NSFont.systemFont(ofSize: 24)))
} 