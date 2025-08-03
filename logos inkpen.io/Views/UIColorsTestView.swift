//
//  UIColorsTestView.swift
//  logos inkpen.io
//
//  Test view to verify UIColors system works in Dark and Light modes
//

import SwiftUI

struct UIColorsTestView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("UIColors Test - \(colorScheme == .dark ? "Dark" : "Light") Mode")
                    .font(.title)
                    .foregroundColor(Color.ui.primaryText)
                
                // Background Colors Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Background Colors")
                        .font(.headline)
                        .foregroundColor(Color.ui.primaryText)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        ColorSwatch(color: Color.ui.windowBackground, name: "Window Background")
                        ColorSwatch(color: Color.ui.controlBackground, name: "Control Background")
                        ColorSwatch(color: Color.ui.lightGrayBackground, name: "Light Gray Background")
                        ColorSwatch(color: Color.ui.veryLightGrayBackground, name: "Very Light Gray")
                        ColorSwatch(color: Color.ui.mediumGrayBackground, name: "Medium Gray")
                        ColorSwatch(color: Color.ui.semiTransparentControlBackground, name: "Semi-Transparent Control")
                    }
                }
                .padding()
                .background(Color.ui.controlBackground)
                .cornerRadius(10)
                
                // Accent Colors Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Accent & Selection Colors")
                        .font(.headline)
                        .foregroundColor(Color.ui.primaryText)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        ColorSwatch(color: Color.ui.primaryBlue, name: "Primary Blue")
                        ColorSwatch(color: Color.ui.lightBlueBackground, name: "Light Blue BG")
                        ColorSwatch(color: Color.ui.mediumBlueBackground, name: "Medium Blue BG")
                        ColorSwatch(color: Color.ui.veryLightBlueBackground, name: "Very Light Blue")
                        ColorSwatch(color: Color.ui.accentColor, name: "Accent Color")
                        ColorSwatch(color: Color.ui.lightAccentBackground, name: "Light Accent BG")
                    }
                }
                .padding()
                .background(Color.ui.lightGrayBackground)
                .cornerRadius(10)
                
                // Border Colors Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Border & Stroke Colors")
                        .font(.headline)
                        .foregroundColor(Color.ui.primaryText)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        BorderSwatch(color: Color.ui.standardBorder, name: "Standard Border")
                        BorderSwatch(color: Color.ui.lightGrayBorder, name: "Light Gray Border")
                        BorderSwatch(color: Color.ui.veryLightGrayBorder, name: "Very Light Gray Border")
                        BorderSwatch(color: Color.ui.separator, name: "Separator")
                    }
                }
                .padding()
                .background(Color.ui.veryLightGrayBackground)
                .cornerRadius(10)
                
                // Text Colors Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Text Colors")
                        .font(.headline)
                        .foregroundColor(Color.ui.primaryText)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Primary Text")
                            .foregroundColor(Color.ui.primaryText)
                        Text("Secondary Text")
                            .foregroundColor(Color.ui.secondaryText)
                        Text("Label Color")
                            .foregroundColor(Color.ui.labelColor)
                        Text("Secondary Label")
                            .foregroundColor(Color.ui.secondaryLabelColor)
                        Text("Tertiary Label")
                            .foregroundColor(Color.ui.tertiaryLabelColor)
                    }
                }
                .padding()
                .background(Color.ui.windowBackground)
                .cornerRadius(10)
                
                // Status Colors Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Status Colors")
                        .font(.headline)
                        .foregroundColor(Color.ui.primaryText)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                        ColorSwatch(color: Color.ui.successColor, name: "Success")
                        ColorSwatch(color: Color.ui.lightSuccessBackground, name: "Light Success BG")
                        ColorSwatch(color: Color.ui.warningColor, name: "Warning")
                        ColorSwatch(color: Color.ui.lightWarningBackground, name: "Light Warning BG")
                        ColorSwatch(color: Color.ui.errorColor, name: "Error")
                        ColorSwatch(color: Color.ui.lightErrorBackground, name: "Light Error BG")
                    }
                }
                .padding()
                .background(Color.ui.mediumGrayBackground)
                .cornerRadius(10)
                
                // Overlay Colors Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Overlay Colors")
                        .font(.headline)
                        .foregroundColor(Color.ui.white)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                        ColorSwatch(color: Color.ui.darkOverlay, name: "Dark Overlay")
                        ColorSwatch(color: Color.ui.semiDarkOverlay, name: "Semi-Dark Overlay")
                        ColorSwatch(color: Color.ui.modalBackground, name: "Modal Background")
                        ColorSwatch(color: Color.ui.whiteOverlay, name: "White Overlay")
                    }
                }
                .padding()
                .background(Color.ui.darkOverlay)
                .cornerRadius(10)
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .background(Color.ui.windowBackground)
        .navigationTitle("UIColors Test")
    }
}

struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 5) {
            Rectangle()
                .fill(color)
                .frame(height: 60)
                .overlay(
                    Rectangle()
                        .stroke(Color.ui.lightGrayBorder, lineWidth: 1)
                )
                .cornerRadius(5)
            
            Text(name)
                .font(.caption)
                .foregroundColor(Color.ui.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

struct BorderSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 5) {
            Rectangle()
                .fill(Color.ui.windowBackground)
                .frame(height: 60)
                .overlay(
                    Rectangle()
                        .stroke(color, lineWidth: 3)
                )
                .cornerRadius(5)
            
            Text(name)
                .font(.caption)
                .foregroundColor(Color.ui.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    UIColorsTestView()
}