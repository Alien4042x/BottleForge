//
//  TweakInstallStateStore.swift
//  BottleForge
//
//  Created by Codex on 09.06.2026.
//

import Foundation

struct TweakInstallStateStore {
    enum Kind {
        case macOS
        case classic

        var defaultsKey: String {
            switch self {
            case .macOS: return "installedTweaks"
            case .classic: return "installedClassicTweaks"
            }
        }

        var keyPrefix: String {
            switch self {
            case .macOS: return ""
            case .classic: return "classic:"
            }
        }
    }

    static func key(
        id: String,
        kind: Kind,
        runtime: SettingsManager.WineRuntime,
        bottle: Bottle
    ) -> String {
        "\(kind.keyPrefix)\(id)@\(runtime.rawValue)@\(bottle.path.path)"
    }

    static func isInstalled(
        id: String,
        kind: Kind,
        runtime: SettingsManager.WineRuntime,
        bottle: Bottle
    ) -> Bool {
        installedKeys(for: kind).contains(key(id: id, kind: kind, runtime: runtime, bottle: bottle))
    }

    static func markInstalled(
        id: String,
        kind: Kind,
        runtime: SettingsManager.WineRuntime,
        bottle: Bottle
    ) {
        let installKey = key(id: id, kind: kind, runtime: runtime, bottle: bottle)
        var keys = installedKeys(for: kind)
        guard !keys.contains(installKey) else { return }
        keys.append(installKey)
        UserDefaults.standard.set(keys, forKey: kind.defaultsKey)
    }

    static func markUninstalled(
        id: String,
        kind: Kind,
        runtime: SettingsManager.WineRuntime,
        bottle: Bottle
    ) {
        let installKey = key(id: id, kind: kind, runtime: runtime, bottle: bottle)
        var keys = installedKeys(for: kind)
        keys.removeAll { $0 == installKey }
        UserDefaults.standard.set(keys, forKey: kind.defaultsKey)
    }

    static func clearBottle(_ bottle: Bottle) {
        for kind in [Kind.macOS, .classic] {
            var keys = installedKeys(for: kind)
            keys.removeAll { $0.contains(bottle.path.path) }
            UserDefaults.standard.set(keys, forKey: kind.defaultsKey)
        }
    }

    private static func installedKeys(for kind: Kind) -> [String] {
        UserDefaults.standard.stringArray(forKey: kind.defaultsKey) ?? []
    }
}
