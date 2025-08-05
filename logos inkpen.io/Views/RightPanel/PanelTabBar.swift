//
//  PanelTabBar.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct PanelTabBar: View {
    @Binding var selectedTab: PanelTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: 8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 2)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(width: 45, height: 40)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    .contentShape(Rectangle()) // Extend hit area to match entire highlight area
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .bottom
        )
    }
} 