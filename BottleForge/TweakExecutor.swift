//
//  TweakExecutor.swift
//  BottleForge
//
//  Created by Radim Veselý on 11.04.2025.
//
//  Copyright (c) 2025 Radim Veselý
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation

struct TweakExecutor {
    static let allowedHosts: Set<String> = [
        "download.zip.dll-files.com",
        "raw.githubusercontent.com"
    ]

    private static func isAllowedHost(_ host: String) -> Bool {
        let normalizedHost = host.lowercased()
        return allowedHosts.contains { allowedHost in
            normalizedHost == allowedHost || normalizedHost.hasSuffix(".\(allowedHost)")
        }
    }
    
    static func apply(
        _ tweak: WineTweak,
        to bottle: Bottle,
        using settings: SettingsManager,
        onError: @escaping (String) -> Void,
        onFinish: @escaping () -> Void
    ) {
        guard let runtime = RuntimeResolver.environment(for: settings),
              runtime.isExecutableAvailable(runtime.wineExecutable) else {
            onError("❌ CrossOver or CXPatcher path is not set.")
            return
        }

        var errorMessages: [String] = []
        let errorQueue = DispatchQueue(label: "BottleForge.TweakExecutor.apply.errors")
        let group = DispatchGroup()

        func appendError(_ message: String) {
            errorQueue.async {
                errorMessages.append(message)
            }
        }

        for file in tweak.files ?? [] {
            // 1️⃣ DLL download
            if let urlStr = file.source_url,
               let dest = file.destination,
               let url = URL(string: urlStr),
               let host = url.host,
               TweakExecutor.isAllowedHost(host) {

                let destinationURL = bottle.path
                    .appendingPathComponent("drive_c/windows/system32")
                    .appendingPathComponent(dest)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    #if DEBUG
                    print("✅ DLL already exists: \(destinationURL.lastPathComponent), skipping download.")
                    #endif
                } else {
                    group.enter()
                    URLSession.shared.dataTask(with: url) { data, _, _ in
                        defer { group.leave() }

                        guard let data = data else {
                            appendError("❌ Failed to download: \(urlStr)")
                            return
                        }

                        do {
                            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            try data.write(to: destinationURL)
                            #if DEBUG
                            print("✅ DLL saved: \(destinationURL.lastPathComponent)")
                            #endif
                        } catch {
                            appendError("❌ Failed to save DLL: \(dest)")
                        }

                    }.resume()
                }
            } else if file.source_url == nil && file.destination == nil {
                #if DEBUG
                print("📦 Skipping download – override only: \(file.dll ?? "??")")
                #endif
            } else {
                // Missing required values, this is an error
                appendError("❌ DLL source is not valid: \(file.source_url ?? "nil")")
            }
            // REG override
            if let dll = file.dll, let mode = file.mode {
                group.enter()

                let process = Process()
                process.executableURL = runtime.wineExecutable
                process.arguments = ["cmd", "/c", "REG ADD HKCU\\Software\\Wine\\DllOverrides /v \(dll) /d \(mode) /f"]

                let environment = runtime.processEnvironment(for: bottle)

                // 💬 Debug: show environment
                #if DEBUG
                print("📦 REG override for \(dll):")
                print("   WINEPREFIX = \(environment["WINEPREFIX"] ?? "nil")")
                print("   CX_BOTTLE  = \(environment["CX_BOTTLE"] ?? "nil")")
                print("   PATH       = \(environment["PATH"] ?? "nil")")
                #endif

                process.environment = environment

                process.terminationHandler = { task in
                    if task.terminationStatus != 0 {
                        appendError("❌ REG ADD for \(dll) failed.")
                    }
                    group.leave()
                }

                do {
                    try process.run()
                } catch {
                    appendError("❌ Failed to start wine process.")
                    group.leave()
                }
            }


        }

        group.notify(queue: .main) {
            errorQueue.async {
                let messages = errorMessages
                DispatchQueue.main.async {
                    if !messages.isEmpty {
                        onError(messages.joined(separator: "\n"))
                    } else {
                        onFinish()
                    }
                }
            }
        }
    }
    
    static func uninstall(
        _ tweak: WineTweak,
        from bottle: Bottle,
        using settings: SettingsManager,
        onError: @escaping (String) -> Void,
        onFinish: @escaping () -> Void
    ) {
        guard let runtime = RuntimeResolver.environment(for: settings),
              runtime.isExecutableAvailable(runtime.wineExecutable) else {
            onError("❌ CrossOver or CXPatcher path is not set.")
            return
        }

        var errorMessages: [String] = []
        let errorQueue = DispatchQueue(label: "BottleForge.TweakExecutor.uninstall.errors")
        let group = DispatchGroup()

        func appendError(_ message: String) {
            errorQueue.async {
                errorMessages.append(message)
            }
        }
        
        for file in tweak.files ?? [] {
            // 1️⃣ REG DELETE override
            if let dll = file.dll {
                group.enter()

                let process = Process()
                process.executableURL = runtime.wineExecutable
                process.arguments = ["cmd", "/c", "REG DELETE HKCU\\Software\\Wine\\DllOverrides /v \(dll) /f"]

                process.environment = runtime.processEnvironment(for: bottle)

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe

                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                        #if DEBUG
                        print("🧯 Uninstall output: \(output)")
                        #endif
                    }
                }

                process.terminationHandler = { task in
                    if task.terminationStatus != 0 {
                        appendError("❌ REG DELETE for \(dll) failed.")
                    }
                    group.leave()
                }

                do {
                    try process.run()
                } catch {
                    appendError("❌ Failed to start wine process for uninstall.")
                    group.leave()
                }
            }

            // 2️⃣ Optionally delete DLL (optional)
            if let dest = file.destination {
                let dllPath = bottle.path
                    .appendingPathComponent("drive_c/windows/system32")
                    .appendingPathComponent(dest)

                if FileManager.default.fileExists(atPath: dllPath.path) {
                    do {
                        try FileManager.default.removeItem(at: dllPath)
                        #if DEBUG
                        print("🗑️ DLL deleted: \(dllPath.lastPathComponent)")
                        #endif
                    } catch {
                        appendError("❌ Failed to delete DLL: \(dllPath.lastPathComponent)")
                    }
                }
            }
        }

        group.notify(queue: .main) {
            errorQueue.async {
                let messages = errorMessages
                DispatchQueue.main.async {
                    if !messages.isEmpty {
                        onError(messages.joined(separator: "\n"))
                    } else {
                        onFinish()
                    }
                }
            }
        }
    }

    // MARK: - Import arbitrary .reg content into bottle registry
    static func importRegistry(
        content: String,
        to bottle: Bottle,
        using settings: SettingsManager,
        onError: @escaping (String) -> Void,
        onFinish: @escaping () -> Void
    ) {
        guard let runtime = RuntimeResolver.environment(for: settings),
              runtime.isExecutableAvailable(runtime.wineExecutable) else {
            onError("❌ CrossOver or CXPatcher path is not set.")
            return
        }

        // Write .reg as UTF-16 LE with BOM for maximum compatibility
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("BottleForge-\(UUID().uuidString).reg")
        do {
            let bom = Data([0xFF, 0xFE])
            var data = content.data(using: .utf16LittleEndian) ?? Data()
            data = bom + data
            try data.write(to: tmp)
        } catch {
            onError("❌ Failed to write temporary .reg file: \(error.localizedDescription)")
            return
        }

        let process = Process()
        process.executableURL = runtime.wineExecutable
        process.arguments = ["regedit", "/S", tmp.path]

        process.environment = runtime.processEnvironment(for: bottle)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { task in
            DispatchQueue.main.async {
                defer { try? FileManager.default.removeItem(at: tmp) }

                if task.terminationStatus != 0 {
                    onError("❌ regedit import failed with code \(task.terminationStatus)")
                } else {
                    onFinish()
                }
            }
        }

        do {
            try process.run()
        } catch {
            onError("❌ Failed to start wine regedit: \(error.localizedDescription)")
        }
    }

}
