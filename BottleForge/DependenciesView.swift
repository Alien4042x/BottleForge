//
//  DependenciesView.swift
//  BottleForge
//
//  Created by Radim Veselý on 17.04.2025.
//
//  Copyright (c) 2025 Radim Veselý
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import SwiftUI
import Foundation

struct DependenciesView: View {
    @EnvironmentObject var settings: SettingsManager

    @State private var isLoadingGStreamer = true
    @State private var isLoadingBrew = true

    @State private var gstreamerInstalled = false
    @State private var gstreamerVersion: String?
    @State private var latestGStreamerVersion: String? = nil
    @State private var isGStreamerOutdated = false
    @State private var errorMessages: [String] = []
    @State private var showErrorModal = false
    @State private var brewVersion: String? = nil
    @State private var latestBrewVersion: String? = nil
    @State private var isBrewOutdated: Bool = false
    @State private var gptkInstallMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "Dependencies", systemImage: "shippingbox")

                Text("Check if required dependencies are installed on your macOS system.")
                    .font(.system(size: 14))

                Divider()

                gstreamerSection
                homebrewSection
                gamePortingToolkitSection

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.trailing, 8)
        }
        .padding()
        .onAppear {
            Task {
                await loadGStreamerStatus()
                await loadBrewStatus()
            }
        }
    }

    private var gstreamerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("GStreamer:")
                    .bold()

                if isLoadingGStreamer {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if gstreamerInstalled {
                    if let version = gstreamerVersion, !isGStreamerOutdated {
                        Label("\(version)", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if let version = gstreamerVersion, let latest = latestGStreamerVersion {
                        Label("(\(version))", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.secondary)
                        Text("Newer available: \(latest)")
                            .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.0))
                        Button("Update") {
                            DependencyChecker.openGStreamerInstaller(for: latest) { errors in
                                errorMessages = errors
                                showErrorModal = true
                            }
                        }
                        .font(.footnote)
                        .buttonStyle(.bordered)
                        .alert("Download Error", isPresented: $showErrorModal) {
                            Button("OK") { errorMessages.removeAll() }
                        } message: {
                            Text(errorMessages.joined(separator: "\n"))
                        }
                    }
                } else {
                    Label("Not Found", systemImage: "xmark.octagon")
                        .foregroundColor(.red)
                }
            }

            if !gstreamerInstalled && !isLoadingGStreamer {
                Button("Download GStreamer") {
                    if let url = URL(string: "https://gstreamer.freedesktop.org/download/") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var homebrewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("Homebrew:")
                    .bold()

                if isLoadingBrew {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    if let version = brewVersion {
                        if isBrewOutdated, let latest = latestBrewVersion {
                            Label("(\(version))", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.secondary)
                            Text("Newer available: \(latest)")
                                .foregroundColor(.orange)
                            Button("Update") {
                                DependencyChecker.updateBrew()
                            }
                            .font(.footnote)
                            .buttonStyle(.bordered)
                        } else {
                            Label("\(version)", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    } else {
                        Label("Not Found", systemImage: "xmark.octagon")
                            .foregroundColor(.red)
                    }
                }
            }

            if !isLoadingBrew && brewVersion == nil {
                Button("Install Homebrew") {
                    DependencyChecker.installHomebrewViaTerminalPrompt()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var gamePortingToolkitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GPTKRequirementBanner(
                title: "Game Porting Toolkit 3",
                requirement: "macOS 15.4+ / stable version",
                tint: .red
            ) {
                openGamePortingToolkit()
            } onInstall: {
                openAppleGPTKFolder()
            }

            GPTKRequirementBanner(
                title: "Game Porting Toolkit 4.0 beta",
                requirement: "Only for macOS 27",
                tint: Color(red: 0.24, green: 0.62, blue: 0.95)
            ) {
                openGamePortingToolkit()
            } onInstall: {
                openAppleGPTKFolder()
            }

            if let gptkInstallMessage {
                Text(gptkInstallMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func openGamePortingToolkit() {
        if let url = URL(string: "https://developer.apple.com/games/game-porting-toolkit/") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAppleGPTKFolder() {
        guard let runtime = RuntimeResolver.environment(for: settings) else {
            gptkInstallMessage = "Select CrossOver or CXPatcher app path in Settings first."
            return
        }

        let target = runtime.appleGPTKDirectory
        if FileManager.default.fileExists(atPath: target.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: target.path)
            gptkInstallMessage = nil
            return
        }

        let parent = target.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parent.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: parent.path)
            gptkInstallMessage = "apple_gptk folder was not found. Opened: \(parent.path)"
        } else {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: runtime.appPath.path)
            gptkInstallMessage = "Target folder was not found: \(target.path)"
        }
    }

    // MARK: - GStreamer status
    private func loadGStreamerStatus() async {
        isLoadingGStreamer = true

        let status = await Task.detached {
            DependencyChecker.checkGStreamerStatus()
        }.value

        gstreamerInstalled = status.isInstalled
        gstreamerVersion = status.version
        latestGStreamerVersion = status.latestVersion

        if let current = gstreamerVersion, let latest = latestGStreamerVersion {
            isGStreamerOutdated = current.compare(latest, options: .numeric) == .orderedAscending
        }

        isLoadingGStreamer = false
    }

    // MARK: - Homebrew status
    private func loadBrewStatus() async {
        isLoadingBrew = true

        let status = await Task.detached {
            DependencyChecker.checkBrewStatus()
        }.value

        brewVersion = status.installedVersion
        latestBrewVersion = status.latestVersion
        isBrewOutdated = status.isOutdated

        isLoadingBrew = false
    }
}

private struct GPTKRequirementBanner: View {
    let title: String
    let requirement: String
    let tint: Color
    let onDownload: () -> Void
    let onInstall: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 15, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(requirement)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 280, alignment: .leading)

            Spacer(minLength: 32)
                .frame(maxWidth: 160)

            HStack(spacing: 8) {
                Button("Download") {
                    onDownload()
                }
                .font(.footnote)
                .buttonStyle(.bordered)

                Button("Install") {
                    onInstall()
                }
                .font(.footnote)
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint.opacity(0.32), lineWidth: 1)
                )
        )
    }
}
