//
//  BrewDetection.swift
//  BottleForge
//
//  Created by Radim Veselý on 17.06.2025.
//
//  Copyright (c) 2025 Radim Veselý
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import AppKit

struct DependencyChecker {
    // MARK: - GStreamer
    struct GStreamerStatus {
        let isInstalled: Bool
        let version: String?
        let latestVersion: String?
        var isOutdated: Bool {
            guard let current = version, let latest = latestVersion else { return false }
            return current.compare(latest, options: .numeric) == .orderedAscending
        }
    }

    // MARK: - Homebrew
    struct BrewStatus {
        let isInstalled: Bool
        let installedVersion: String?
        let latestVersion: String?
        var isOutdated: Bool {
            guard let current = installedVersion, let latest = latestVersion else { return false }
            return current.compare(latest, options: .numeric) == .orderedAscending
        }
    }

    // MARK: - Public Interface

    static func checkGStreamerStatus() -> GStreamerStatus {
        let plistPath = "/Library/Frameworks/GStreamer.framework/Versions/1.0/Resources/Info.plist"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any],
              let version = dict["CFBundleShortVersionString"] as? String else {
            return GStreamerStatus(isInstalled: false, version: nil, latestVersion: nil)
        }

        let latest = fetchLatestGStreamerVersionSync()
        return GStreamerStatus(isInstalled: true, version: version, latestVersion: latest)
    }

    static func checkBrewStatus() -> BrewStatus {
        guard let installedPath = getBrewBinaryPath() else {
            return BrewStatus(isInstalled: false, installedVersion: nil, latestVersion: nil)
        }

        let installedVersion = getBrewVersion(at: installedPath)
        let latestVersion = getBrewLatestVersion()

        return BrewStatus(isInstalled: true, installedVersion: installedVersion, latestVersion: latestVersion)
    }

    // MARK: - Actions

    static func openGStreamerInstaller(for version: String, onError: @escaping ([String]) -> Void) {
        let baseURL = "https://gstreamer.freedesktop.org/data/pkg/osx/\(version)/"
        guard let url = URL(string: baseURL) else {
            onError(["❌ Invalid GStreamer version URL"])
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                onError(["❌ Unable to load GStreamer index for version \(version)"])
                return
            }

            let pattern = #"href=\"(gstreamer-[\d\.]+-\#(version)-universal\.pkg)\""#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let pkg = String(html[range])
                let fullURL = baseURL + pkg
                if let url = URL(string: fullURL) {
                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    onError(["❌ Invalid installer URL: \(fullURL)"])
                }
            } else {
                onError(["❌ No installer found in \(baseURL)"])
            }
        }.resume()
    }

    static func installHomebrewViaTerminalPrompt() {
        let alert = NSAlert()
        alert.messageText = "Install Homebrew"
        alert.informativeText = "This will open Terminal and run the Homebrew installer."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let scriptContent = """
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            read -n 1
            """
            let tempScriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("install_brew.sh")
            try? scriptContent.write(to: tempScriptURL, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", tempScriptURL.path]
            try? process.run()
        }
    }

    static func updateBrew() {
        guard let path = getBrewBinaryPath() else { return }

        let alert = NSAlert()
        alert.messageText = "Update Homebrew"
        alert.informativeText = "This will open Terminal and run `brew update`."
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let scriptContent = """
            \"\(path)\" update
            read -n 1
            """
            let tempScriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("update_brew.sh")
            try? scriptContent.write(to: tempScriptURL, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", tempScriptURL.path]
            try? process.run()
        }
    }

    // MARK: - Helpers

    public static func getBrewBinaryPath() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    private static func getBrewVersion(at path: String) -> String? {
        runCommand([path, "--version"])?
            .split(separator: "\n").first?
            .split(separator: " ").dropFirst().first
            .map(String.init)
    }

    static func getBrewLatestVersion() -> String? {
        guard let url = URL(string: "https://formulae.brew.sh/api/homebrew.json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let brew = json["brew"] as? [String: Any],
              let version = brew["versions"] as? [String: Any],
              let stable = version["stable"] as? String else {
            return nil
        }

        return stable
    }

    private static func fetchLatestGStreamerVersionSync() -> String? {
        guard let url = URL(string: "https://gstreamer.freedesktop.org/data/pkg/osx/"),
              let data = try? Data(contentsOf: url),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        let regex = try! NSRegularExpression(pattern: #">(\d+\.\d+\.\d+)/<"#)
        let versions = regex
            .matches(in: html, range: NSRange(html.startIndex..., in: html))
            .compactMap { match -> String? in
                Range(match.range(at: 1), in: html).map { String(html[$0]) }
            }

        return versions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }.first
    }

    private static func runCommand(_ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    // MARK: - Winetricks Utilities

    static func isToolInstalledViaBrew(_ tool: String) -> Bool {
        let cellarPaths = ["/opt/homebrew/Cellar", "/usr/local/Cellar"]
        for path in cellarPaths {
            let toolPath = "\(path)/\(tool)"
            if FileManager.default.fileExists(atPath: toolPath) {
                return true
            }
        }
        return false
    }
    
    static func isToolInstalled(_ tool: String) -> Bool {
        return isToolInstalledViaBrew(tool) || isToolInSystem(tool)
    }

    static func isToolInSystem(_ tool: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [tool]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        } catch {
            return false
        }

        return false
    }

    static func missingWinetricksDependencies() -> [String] {
        let required = ["cabextract", "wget", "unzip"]
        return required.filter { !isToolInstalled($0) }
    }
}
