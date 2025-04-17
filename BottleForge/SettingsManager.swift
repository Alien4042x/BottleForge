//
//  SettingsManager.swift
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
import SwiftUI

class SettingsManager: ObservableObject {
    @Published var crossoverAppPath: URL?
    @Published var cxpatcherAppPath: URL?

    init() {
        load()
    }
    
    enum WineRuntime: String, CaseIterable, Identifiable {
        case crossover
        case cxpatcher

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .crossover: return "CrossOver"
            case .cxpatcher: return "CXPatcher"
            }
        }
    }

    public func save() {
        let defaults = UserDefaults.standard

        if let crossoverAppPath = crossoverAppPath {
            defaults.set(crossoverAppPath.path, forKey: "crossoverAppPath")
        } else {
            defaults.removeObject(forKey: "crossoverAppPath")
        }

        if let cxpatcherAppPath = cxpatcherAppPath {
            defaults.set(cxpatcherAppPath.path, forKey: "cxpatcherAppPath")
        } else {
            defaults.removeObject(forKey: "cxpatcherAppPath")
        }
        defaults.set(selectedRuntime.rawValue, forKey: "selectedWineRuntime")
    }
    
    @Published var selectedRuntime: WineRuntime = .crossover {
        didSet { save() }
    }

    private func load() {
        let defaults = UserDefaults.standard

        if let crossoverPath = defaults.string(forKey: "crossoverAppPath") {
            #if DEBUG
            print("📂 Loaded crossoverAppPath: \(crossoverPath)")
            #endif
            self.crossoverAppPath = URL(fileURLWithPath: crossoverPath)
        } else {
            #if DEBUG
            print("⚠️ crossoverAppPath not found in defaults")
            #endif
        }

        if let cxpatcherPath = defaults.string(forKey: "cxpatcherAppPath") {
            #if DEBUG
            print("📂 Loaded cxpatcherAppPath: \(cxpatcherPath)")
            #endif
            self.cxpatcherAppPath = URL(fileURLWithPath: cxpatcherPath)
        } else {
            #if DEBUG
            print("⚠️ cxpatcherAppPath not found in defaults")
            #endif
        }
        if let runtimeRaw = defaults.string(forKey: "selectedWineRuntime"),
           let runtime = WineRuntime(rawValue: runtimeRaw) {
            self.selectedRuntime = runtime
        } else {
            self.selectedRuntime = .crossover
        }
    }

    func clearCrossoverAppPath() {
        crossoverAppPath = nil
    }

    func clearCxpatcherAppPath() {
        cxpatcherAppPath = nil
    }

    var wineExecutable: URL? {
        let app = selectedRuntime == .crossover ? crossoverAppPath : cxpatcherAppPath
        guard let app else { return nil }

        let winePath = app
            .appendingPathComponent("Contents")
            .appendingPathComponent("SharedSupport")
            .appendingPathComponent("CrossOver")
            .appendingPathComponent("CrossOver-Hosted Application")
            .appendingPathComponent("wine")

        return FileManager.default.fileExists(atPath: winePath.path) ? winePath : nil
    }
    
    var regeditExecutable: URL? {
        let selectedApp: URL? = {
            switch selectedRuntime {
            case .crossover: return crossoverAppPath
            case .cxpatcher: return cxpatcherAppPath
            }
        }()

        guard let app = selectedApp else { return nil }

        let path = app
            .appendingPathComponent("Contents")
            .appendingPathComponent("SharedSupport")
            .appendingPathComponent("CrossOver")
            .appendingPathComponent("CrossOver-Hosted Application")
            .appendingPathComponent("regedit")

        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    var isValid: Bool {
        crossoverAppPath != nil || cxpatcherAppPath != nil
    }

    var hasExecutables: Bool {
        wineExecutable != nil && regeditExecutable != nil
    }
}
