//
//  ClassicTweakExecutor.swift
//  BottleForge
//
//  Created by Radim Veselý on 15.06.2025.
//
//  Copyright (c) 2025 Radim Veselý
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import AppKit

struct ClassicTweakExecutor {
    // MARK: - Install Classic Tweak
    static func install(
        _ tweak: ClassicTweak,
        to bottle: Bottle,
        using settings: SettingsManager,
        onError: @escaping (String) -> Void,
        onFinish: @escaping () -> Void
    ) {
        let missingTools = DependencyChecker.missingWinetricksDependencies()
        guard missingTools.isEmpty else {
            #if DEBUG
            print("⚠️ Missing: \(missingTools.joined(separator: ", "))")
            #endif
            installToolsViaTerminalPrompt(missing: missingTools, onError: onError)
            return
        }

        guard let appPath = settings.selectedRuntime == .crossover ? settings.crossoverAppPath : settings.cxpatcherAppPath else {
            onError("❌ CrossOver or CXPatcher path is not set.")
            return
        }

        let wineExec = appPath.appendingPathComponent("Contents/SharedSupport/CrossOver/bin/wine")

        guard let winetricksPath = extractEmbeddedWinetricksScript(onError: onError) else {
            return
        }
        
        guard let wrapperScript = createWrapperScript(for: bottle, wineExec: wineExec, winetricksPath: winetricksPath, onError: onError) else {
            onError("❌ Failed to create wine wrapper script.")
            return
        }

        let wineboot = Process()
        wineboot.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
        wineboot.arguments = ["-x86_64", wineExec.path, "wineboot"]

        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = bottle.path.path
        wineboot.environment = env

        do {
            try wineboot.run()
            wineboot.waitUntilExit()
        } catch {
            onError("❌ Failed to run wineboot: \(error.localizedDescription)")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
        process.arguments = ["-x86_64", wrapperScript.path, tweak.id]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        process.terminationHandler = { task in
            DispatchQueue.main.async {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                print("[winetricks output] \(output)")

                if task.terminationStatus != 0 {
                    if output.contains("does not work on a 64-bit installation") {
                        onError("❌ The tweak \"\(tweak.id)\" requires a 32-bit Wine prefix (WINEARCH=win32).")
                    } else {
                        onError("❌ winetricks \(tweak.id) failed with code \(task.terminationStatus)\n\n\(output)")
                    }
                } else {
                    onFinish()
                }
            }
        }

        do {
            try process.run()
        } catch {
            onError("❌ Failed to start winetricks process.")
        }
    }

    // MARK: - Uninstall Classic Tweak
    static func uninstall(
        _ tweak: ClassicTweak,
        from bottle: Bottle,
        using settings: SettingsManager,
        onError: @escaping (String) -> Void,
        onFinish: @escaping () -> Void
    ) {
        install(tweak, to: bottle, using: settings, onError: onError, onFinish: onFinish)
    }

    // MARK: - Extract Embedded winetricks Script
    static func extractEmbeddedWinetricksScript(onError: @escaping (String) -> Void) -> URL? {
        guard let scriptURL = Bundle.main.url(forResource: "winetricks", withExtension: nil) else {
            onError("❌ winetricks not found in bundle")
            return nil
        }

        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("winetricks")

        do {
            if FileManager.default.fileExists(atPath: tmpURL.path) {
                try FileManager.default.removeItem(at: tmpURL)
            }
            try FileManager.default.copyItem(at: scriptURL, to: tmpURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpURL.path)
            return tmpURL
        } catch {
            onError("❌ Failed to copy/make executable: \(error)")
            return nil
        }
    }

    // MARK: - Create winetricks Wrapper Script
    static func createWrapperScript(
        for bottle: Bottle,
        wineExec: URL,
        winetricksPath: URL,
        onError: @escaping (String) -> Void
    ) -> URL? {
        let tmpPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("winetricks-wrapper.sh")
        let wineServer = wineExec.deletingLastPathComponent().appendingPathComponent("wineserver").path

        let scriptContent = """
        #!/bin/bash
        export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
        export WINEPREFIX="\(bottle.path.path)"
        export CX_BOTTLE="\(bottle.name)"
        export CX_BOTTLE_PATH="\(bottle.path.deletingLastPathComponent().path)"
        export WINETRICKS_ARCH=win64
        export WINE="\(wineExec.path)"
        export WINESERVER="\(wineServer)"
        export WINELOADER="\(wineExec.path)"
        export WINEDEBUG=-all

        /bin/bash "\(winetricksPath.path)" "$@"
        """

        do {
            try scriptContent.write(to: tmpPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpPath.path)
            return tmpPath
        } catch {
            onError("❌ Failed to create wine-wrapper.sh: \(error)")
            return nil
        }
    }

    // MARK: - Install Missing Tools via Terminal
    private static func installToolsViaTerminalPrompt(
        missing: [String],
        onError: @escaping (String) -> Void
    ) {
        guard let brewPath = DependencyChecker.getBrewBinaryPath() else {
            onError("❌ Homebrew not found")
            return
        }

        let installCommand = "\(brewPath) install \(missing.joined(separator: " "))"
        let alert = NSAlert()
        alert.messageText = "Missing dependencies"
        alert.informativeText = "Required tools are missing: \(missing.joined(separator: ", ")).\nDo you want to install them via Homebrew?"
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let tempScript = """
            #!/bin/bash
            echo "Installing required tools..."
            \(installCommand)
            echo "Done. Press any key to close."
            read -n 1
            """
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("install_deps.sh")
            do {
                try tempScript.write(to: tempURL, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempURL.path)

                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                proc.arguments = ["-a", "Terminal", tempURL.path]
                try proc.run()

                #if DEBUG
                print("✅ Started installing: \(missing.joined(separator: ", "))")
                #endif
            } catch {
                onError("❌ Failed to create or run install script: \(error)")
            }
        } else {
            onError("❌ User cancelled installation.")
        }
    }
}
