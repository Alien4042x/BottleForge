//
//  BottleForgeApp.swift
//  BottleForge
//
//  Created by Radim Veselý on 28.03.2025.
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
                .frame(width: 1440, height: 720)
                .fixedSize()
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
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

