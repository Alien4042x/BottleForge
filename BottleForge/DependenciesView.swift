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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🔧 Dependencies")
                .font(.title)

            Text("Check if required dependencies are installed on your macOS system.")
                .font(.system(size: 14))

            Divider()

            // MARK: - GStreamer
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

            // MARK: - Homebrew
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

            // MARK: - Game Porting Toolkit
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Text("Game Porting Toolkit 3:")
                        .bold()
                    Button("Download") {
                        if let url = URL(string: "https://developer.apple.com/games/game-porting-toolkit/") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.footnote)
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            Task {
                await loadGStreamerStatus()
                await loadBrewStatus()
            }
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
