//
//  ContentView.swift
//  Test
//
//  Created by Todd Bruss on 7/21/25.
//

import SwiftUI
import CoreText

struct TextBoxContentView: View {
    var body: some View {
        TextEditorCanvas()
    }
}

struct TextEditorCanvas: View {
    @StateObject private var textEditor = TextEditorViewModel()
    @State private var showingFontPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Toolbar
            VStack(spacing: 10) {
                // First row - Font picker and buttons
                HStack {
                    Button("Font: \(textEditor.safeFontName)") {
                        showingFontPicker = true
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Button("Convert to Path") {
                        textEditor.convertToPath()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Clear Paths") {
                        textEditor.clearPaths()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    if textEditor.textPath != nil {
                        Button(textEditor.showPath ? "Show Text" : "Show Paths") {
                            textEditor.toggleDisplay()
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(textEditor.autoExpandVertically ? "Auto-Expand: ON" : "Auto-Expand: OFF") {
                        textEditor.autoExpandVertically.toggle()
                    }
                    .padding()
                    .background(textEditor.autoExpandVertically ? Color.orange : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // Second row - Sliders
                HStack {
                    Text("Size: \(Int(textEditor.fontSize))")
                    
                    Slider(value: $textEditor.fontSize, in: 8...72)
                        .frame(width: 200)
                    
                    Spacer()
                    
                    Text("Line Spacing: \(Int(textEditor.lineSpacing))")
                    
                    Slider(value: $textEditor.lineSpacing, in: -20...20)
                        .frame(width: 200)
                }
            }
            .padding()
            
            // Color Controls
            HStack {
                VStack {
                    Text("Fill Color")
                    ColorPicker("", selection: $textEditor.textColor)
                        .frame(width: 50, height: 30)
                }
                
                Spacer()
            }
            .padding()
            
            // Alignment Controls
            HStack {
                Text("Alignment:")
                
                Picker("", selection: $textEditor.textAlignment) {
                    Text("Left").tag(NSTextAlignment.left)
                    Text("Center").tag(NSTextAlignment.center)
                    Text("Right").tag(NSTextAlignment.right)
                    Text("Justified").tag(NSTextAlignment.justified)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 280)
                
                Spacer()
            }
            .padding()
            
            // Canvas
            ZStack {
                Color.gray
                    .border(Color.gray, width: 1)
                
                EditableTextCanvas(viewModel: textEditor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingFontPicker) {
            FontPickerView(selectedFont: $textEditor.selectedFont)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    ContentView()
}
