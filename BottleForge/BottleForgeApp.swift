//
//  BottleForgeApp.swift
//  BottleForge
//
//  Created by Radim Veselý on 28.03.2025.
//
//  Copyright (c) 2025 Radim Veselý
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import SwiftUI

@main
struct BottleForgeApp: App {
    @StateObject var appState = AppState()
    @StateObject var settings = SettingsManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(state: appState)
                .frame(minWidth: 1280, minHeight: 800)
                .environmentObject(settings)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BottleForge") {
                    showCustomAboutWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force dark appearance for a modern dark UI
        NSApp.appearance = NSAppearance(named: .darkAqua)
        if let window = NSApplication.shared.windows.first {
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            // Use an opaque, modern dark background (not pure black)
            window.isOpaque = true
            window.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1.0)
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
