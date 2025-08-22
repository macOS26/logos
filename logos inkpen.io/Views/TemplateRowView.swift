//
//  TemplateRowView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

/// Individual Template Row
struct TemplateRowView: View {
    let template: TemplateManager.TemplateType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconName)
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(template.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.title3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
