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
        if let window = NSApplication.shared.windows.first {
            window.standardWindowButton(.zoomButton)?.isHidden = true
            // Enable true vibrancy: transparent window + full-size content
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
