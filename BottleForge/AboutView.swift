//
//  AboutView.swift
//  BottleForge
//
//  Created by Radim Veselý on 15.04.2025.
//

import SwiftUI

struct AboutView: View {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1001"
    
    var body: some View {
        VStack(spacing: 20) {
            // Logo
            Image("about_icon")
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .cornerRadius(20)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(white: 0.40))
                )
                .padding(.top, 20)

            Text("BottleForge")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text("Powerful Wine environment manager for macOS.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("by Alien4042x")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Version \(version) (Build \(build))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("BottleForge is licensed under the Mozilla Public License 2.0 (MPL).")
                .font(.caption)
                .foregroundColor(.secondary)
            Link("View License", destination: URL(string: "https://www.mozilla.org/MPL/2.0/")!)
                .font(.caption)

            Divider()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        Text("🧪 Wine Tweaks & Fixes")
                        Text("🩺 Diagnostics for DLL/runtime issues")
                        Text("🗂️ File Explorer for Bottle contents")
                        Text("🍷 Support for CrossOver & CXPatcher")
                    }
                    .font(.body)
                    .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("DEVELOPMENT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Alien4042x")
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .frame(width: 520, height: 520)
    }
}

func showCustomAboutWindow() {
    let aboutView = AboutView()
    let hostingController = NSHostingController(rootView: aboutView)

    let window = NSWindow(contentViewController: hostingController)
    window.title = "About"
    window.setContentSize(NSSize(width: 500, height: 400))
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.isReleasedWhenClosed = false
    window.center()
    window.makeKeyAndOrderFront(nil)
}
