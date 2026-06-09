//
//  RuntimeResolver.swift
//  BottleForge
//
//  Created by Codex on 09.06.2026.
//

import Foundation

struct WineRuntimeEnvironment {
    let runtime: SettingsManager.WineRuntime
    let appPath: URL

    var hostedApplicationDirectory: URL {
        appPath
            .appendingPathComponent("Contents")
            .appendingPathComponent("SharedSupport")
            .appendingPathComponent("CrossOver")
            .appendingPathComponent("CrossOver-Hosted Application")
    }

    var binDirectory: URL {
        appPath
            .appendingPathComponent("Contents")
            .appendingPathComponent("SharedSupport")
            .appendingPathComponent("CrossOver")
            .appendingPathComponent("bin")
    }

    var appleGPTKDirectory: URL {
        appPath
            .appendingPathComponent("Contents")
            .appendingPathComponent("SharedSupport")
            .appendingPathComponent("CrossOver")
            .appendingPathComponent("lib64")
            .appendingPathComponent("apple_gptk")
    }

    var wineExecutable: URL {
        hostedApplicationDirectory.appendingPathComponent("wine")
    }

    var regeditExecutable: URL {
        hostedApplicationDirectory.appendingPathComponent("regedit")
    }

    var classicWineExecutable: URL {
        binDirectory.appendingPathComponent("wine")
    }

    var classicWineServerExecutable: URL {
        binDirectory.appendingPathComponent("wineserver")
    }

    func isExecutableAvailable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }

    func processEnvironment(for bottle: Bottle) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = bottle.path.path
        environment["CX_BOTTLE"] = bottle.name
        environment["PATH"] = hostedApplicationDirectory.path + ":" + (environment["PATH"] ?? "")
        environment["USER"] = NSUserName()
        environment["HOME"] = NSHomeDirectory()
        return environment
    }
}

struct RuntimeResolver {
    static func appPath(for settings: SettingsManager) -> URL? {
        switch settings.selectedRuntime {
        case .crossover:
            return settings.crossoverAppPath
        case .cxpatcher:
            return settings.cxpatcherAppPath
        }
    }

    static func environment(for settings: SettingsManager) -> WineRuntimeEnvironment? {
        guard let appPath = appPath(for: settings) else { return nil }
        return WineRuntimeEnvironment(runtime: settings.selectedRuntime, appPath: appPath)
    }
}
