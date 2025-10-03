//
//  StylusToggleButton.swift
//  logos inkpen.io
//
//  Custom toggle button that works with stylus input
//

import SwiftUI

struct StylusToggleButton: View {
    @Binding var isOn: Bool
    var label: String = ""
    var onChange: ((Bool) -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            if !label.isEmpty {
                Text(label)
                    .foregroundColor(.primary)
            }

            Button {
                isOn.toggle()
                onChange?(isOn)
            } label: {
                ZStack {
                    // Background track
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 44, height: 24)

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .offset(x: isOn ? 10 : -10)
                        .animation(.easeInOut(duration: 0.2), value: isOn)
                }
                .frame(width: 44, height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}

// Convenience modifier to replace Toggle with StylusToggleButton
struct StylusToggleModifier: ViewModifier {
    @Binding var isOn: Bool
    var label: String = ""
    var onChange: ((Bool) -> Void)?

    func body(content: Content) -> some View {
        StylusToggleButton(isOn: $isOn, label: label, onChange: onChange)
    }
}

extension View {
    func stylusToggle(isOn: Binding<Bool>, label: String = "", onChange: ((Bool) -> Void)? = nil) -> some View {
        StylusToggleButton(isOn: isOn, label: label, onChange: onChange)
    }
}