//
//  InfoLabel.swift
//  BottleForge
//
//  Created by Radim Veselý on 16.04.2025.
//

import SwiftUI

struct InfoLabel: View {
    var text: String
    @State private var showPopover = false

    var body: some View {
        Button(action: {
            showPopover.toggle()
        }) {
            Image(systemName: "info.circle")
                .foregroundColor(.accentColor)
                .imageScale(.small)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            Text(text)
                .padding()
        }
    }
}
