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
    
    static func apply(
        _ tweak: WineTweak,
        to bottle: Bottle,
        using settings: SettingsManager,
        onError: @escaping (String) -> Void,
        onFinish: @escaping () -> Void
    ) {
        guard let appPath = settings.selectedRuntime == .crossover ? settings.crossoverAppPath : settings.cxpatcherAppPath else {
            onError("❌ CrossOver or CXPatcher path is not set.")
            return
        }

        let wineExec = appPath
            .appendingPathComponent("Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine")

        var errorMessages: [String] = []
        let group = DispatchGroup()

        for file in tweak.files ?? [] {
            // 1️⃣ DLL download
            if let urlStr = file.source_url,
               let dest = file.destination,
               let url = URL(string: urlStr),
               let host = url.host,
               TweakExecutor.allowedHosts.contains(where: { host.contains($0) }) {

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
                            errorMessages.append("❌ Failed to download: \(urlStr)")
                            return
                        }

                        do {
                            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            try data.write(to: destinationURL)
                            #if DEBUG
                            print("✅ DLL saved: \(destinationURL.lastPathComponent)")
                            #endif
                        } catch {
                            errorMessages.append("❌ Failed to save DLL: \(dest)")
                        }

                    }.resume()
                }
            } else if file.source_url == nil && file.destination == nil {
                #if DEBUG
                print("📦 Skipping download – override only: \(file.dll ?? "??")")
                #endif
            } else {
                // Missing required values, this is an error
                errorMessages.append("❌ DLL source is not valid: \(file.source_url ?? "nil")")
            }
            // REG override
            if let dll = file.dll, let mode = file.mode {
                group.enter()

                let process = Process()
                process.executableURL = wineExec
                process.arguments = ["cmd", "/c", "REG ADD HKCU\\Software\\Wine\\DllOverrides /v \(dll) /d \(mode) /f"]

                // 🌍 Set environment like in terminal
                var environment = ProcessInfo.processInfo.environment
                environment["WINEPREFIX"] = bottle.path.path
                environment["CX_BOTTLE"] = bottle.name // Přidáme i CX_BOTTLE
                environment["PATH"] = wineExec.deletingLastPathComponent().path + ":" + (environment["PATH"] ?? "")
                environment["USER"] = NSUserName()
                environment["HOME"] = NSHomeDirectory()

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
                        errorMessages.append("❌ REG ADD for \(dll) failed.")
                    }
                    group.leave()
                }

                do {
                    try process.run()
                } catch {
                    errorMessages.append("❌ Failed to start wine process.")
                    group.leave()
                }
            }


        }

        group.notify(queue: .main) {
            if !errorMessages.isEmpty {
                onError(errorMessages.joined(separator: "\n"))
            } else {
                onFinish()
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
        guard let appPath = settings.selectedRuntime == .crossover ? settings.crossoverAppPath : settings.cxpatcherAppPath else {
            onError("❌ CrossOver or CXPatcher path is not set.")
            return
        }

        let wineExec = appPath
            .appendingPathComponent("Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine")

        var errorMessages: [String] = []
        let group = DispatchGroup()
        
        for file in tweak.files ?? [] {
            // 1️⃣ REG DELETE override
            if let dll = file.dll {
                group.enter()

                let process = Process()
                process.executableURL = wineExec
                process.arguments = ["cmd", "/c", "REG DELETE HKCU\\Software\\Wine\\DllOverrides /v \(dll) /f"]

                var environment = ProcessInfo.processInfo.environment
                environment["WINEPREFIX"] = bottle.path.path
                environment["CX_BOTTLE"] = bottle.name
                environment["PATH"] = wineExec.deletingLastPathComponent().path + ":" + (environment["PATH"] ?? "")
                environment["USER"] = NSUserName()
                environment["HOME"] = NSHomeDirectory()

                process.environment = environment

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
                        errorMessages.append("❌ REG DELETE for \(dll) failed.")
                    }
                    group.leave()
                }

                do {
                    try process.run()
                } catch {
                    errorMessages.append("❌ Failed to start wine process for uninstall.")
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
                        errorMessages.append("❌ Failed to delete DLL: \(dllPath.lastPathComponent)")
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if !errorMessages.isEmpty {
                onError(errorMessages.joined(separator: "\n"))
            } else {
                onFinish()
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
        guard let appPath = settings.selectedRuntime == .crossover ? settings.crossoverAppPath : settings.cxpatcherAppPath else {
            onError("❌ CrossOver or CXPatcher path is not set.")
            return
        }

        let wineExec = appPath
            .appendingPathComponent("Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine")

        // Write .reg as UTF-16 LE with BOM for maximum compatibility
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("import.reg")
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
        process.executableURL = wineExec
        process.arguments = ["regedit", "/S", tmp.path]

        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = bottle.path.path
        environment["CX_BOTTLE"] = bottle.name
        environment["PATH"] = wineExec.deletingLastPathComponent().path + ":" + (environment["PATH"] ?? "")
        environment["USER"] = NSUserName()
        environment["HOME"] = NSHomeDirectory()
        process.environment = environment

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
