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
    @State private var checkingLocal = true
    @State private var checkingRemote = true

    @State private var gstreamerInstalled = false
    @State private var gstreamerVersion: String?
    @State private var latestGStreamerVersion: String? = nil
    @State private var isOutdated: Bool = false

    @State private var errorMessages: [String] = []
    @State private var showErrorModal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🔧 Dependencies")
                .font(.title)

            Text("Check if required dependencies are installed on your macOS system.")
                .font(.system(size: 14))

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Text("GStreamer:")
                        .bold()

                    // show spinner until both checks done
                    if checkingLocal || checkingRemote {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())

                    } else if gstreamerInstalled {
                        // Up‑to‑date
                        if let version = gstreamerVersion, !isOutdated {
                            Label("\(version)", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)

                        // Outdated
                        } else if let version = gstreamerVersion, let latest = latestGStreamerVersion {
                            Label("(\(version))", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.secondary)
                            Text("Newer available: \(latest)")
                                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.0) )
                            Button("Update") {
                                fetchUpdate(for: latest)
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
                // download when missing
                if !gstreamerInstalled {
                    Button("Download GStreamer") {
                        if let url = URL(string: "https://gstreamer.freedesktop.org/download/") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            checkGStreamerLocal()
            fetchLatestGStreamerVersion()
        }
    }

    // Local
    private func checkGStreamerLocal() {
        DispatchQueue.global(qos: .background).async {
            let result = GStreamerStatus.check()
            DispatchQueue.main.async {
                self.gstreamerInstalled = result.isInstalled
                self.gstreamerVersion = result.version
                self.checkingLocal = false
            }
        }
    }

    // Remote
    private func fetchLatestGStreamerVersion() {
        guard let url = URL(string: "https://gstreamer.freedesktop.org/data/pkg/osx/") else {
            self.checkingRemote = false
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { DispatchQueue.main.async { self.checkingRemote = false } }
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else { return }

            let regex = try! NSRegularExpression(pattern: #">(\d+\.\d+\.\d+)/<"#)
            let versions = regex
                .matches(in: html, range: NSRange(html.startIndex..., in: html))
                .compactMap { match -> String? in
                    Range(match.range(at: 1), in: html).map { String(html[$0]) }
                }
            if let latest = versions.sorted(by: { $0.compare($1, options: .numeric) == .orderedDescending }).first {
                DispatchQueue.main.async {
                    self.latestGStreamerVersion = latest
                    if let local = self.gstreamerVersion {
                        self.isOutdated = local.compare(latest, options: .numeric) == .orderedAscending
                    }
                }
            }
        }.resume()
    }

    // Fetch package name + open
    private func fetchUpdate(for version: String) {
        let listURL = "https://gstreamer.freedesktop.org/data/pkg/osx/\(version)/"
        guard let url = URL(string: listURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.errorMessages = ["❌ Unable to load index for \(version)"]
                    self.showErrorModal = true
                }
                return
            }

            // look for gstreamer-<x>-<version>-universal.pkg
            let pattern = #"href=\"(gstreamer-[\d\.]+-\#(version)-universal\.pkg)\""#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let pkg = String(html[range])
                let fullURL = listURL + pkg
                DispatchQueue.main.async {
                    if let url = URL(string: fullURL) {
                        NSWorkspace.shared.open(url)
                    } else {
                        self.errorMessages = ["❌ Invalid URL: \(fullURL)"]
                        self.showErrorModal = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessages = ["❌ No installer found in \(listURL)"]
                    self.showErrorModal = true
                }
            }
        }.resume()
    }
}

struct GStreamerStatus {
    let isInstalled: Bool
    let version: String?
    static func check() -> GStreamerStatus {
        let path = "/Library/Frameworks/GStreamer.framework/Versions/1.0/Resources/Info.plist"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any],
              let v = dict["CFBundleShortVersionString"] as? String
        else {
            return .init(isInstalled: false, version: nil)
        }
        return .init(isInstalled: true, version: v)
    }
}
