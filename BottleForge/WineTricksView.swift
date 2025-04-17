//
//  WineTricksView.swift
//  BottleForge
//
//  Created by Radim Veselý on 08.04.2025.
//
//  Copyright (c) 2025 Radim Veselý
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//


import SwiftUI

struct WineTweak: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let description_long: String?
    let category: String
    let company: String?
    let platforms: [String]?
    let conflicts_with: [String]?
    let steps: [String]?
    let files: [WineTweakFile]?
    let version: String?
    let date: String?

    var installed: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id, title, description, description_long, category, company, platforms, conflicts_with, steps, files, version, date
    }
}

struct WineTweakFile: Codable, Hashable {
    let name: String?
    let source_url: String?
    let destination: String?
    let dll: String?
    let mode: String?
}

struct WineTweakDatabase: Codable {
    let version: Int
    let categories: [WineTweakCategory]
    let tweaks: [WineTweak]
}

struct WineTweakCategory: Codable {
    let id: String
    let name: String
}

struct WineTricksView: View {
    @ObservedObject var appState: AppState
    @EnvironmentObject var settings: SettingsManager
    @State private var tweaks: [WineTweak] = []
    @State private var filter: String = ""
    @State private var loadingTweaks = false
    @State private var selectedCategory: String? = nil
    @State private var showErrorAlert = false
    @State private var selectedTweak: WineTweak? = nil
    @State private var showDetailModal = false

    @State private var errorMessage = ""

    let tweaksPath = URL(string: "https://raw.githubusercontent.com/Alien4042x/winemactricks-json/main/winemactricks.json")!

    var filteredTweaks: [WineTweak] {
        if filter.isEmpty && selectedCategory == nil {
            return tweaks
        }

        return tweaks.filter { tweak in
            let lowercasedFilter = filter.lowercased()

            let matchesText =
                tweak.title.lowercased().contains(lowercasedFilter) ||
                tweak.description.lowercased().contains(lowercasedFilter) ||
                (tweak.description_long?.lowercased().contains(lowercasedFilter) ?? false) ||
                (tweak.company?.lowercased().contains(lowercasedFilter) ?? false) ||
                (tweak.platforms?.contains(where: { $0.lowercased().contains(lowercasedFilter) }) ?? false) ||
                tweak.category.lowercased().contains(lowercasedFilter)

            let matchesCategory = selectedCategory == nil || tweak.category == selectedCategory

            return matchesText && matchesCategory
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🍷 WineTricks macOS")
                .font(.title)

            Text("Custom Winetricks-style tweaks tailored for macOS with support for CrossOver and CXPatcher.")
                .font(.system(size: 14))

            Divider()

            HStack {
                TextField("Search tweak...", text: $filter)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()
                Button("🧹 Clear Cache for This Bottle") {
                    if let bottle = appState.selectedBottle {
                        clearBottleCache(bottle)
                        loadTweaks() // ← reload immediately after
                    }
                }
                .foregroundColor(.red)
            }
            .padding(.bottom)

            if loadingTweaks {
                ProgressView("Loading tweaks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredTweaks) { tweak in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tweak.title)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(tweak.description)
                                        .font(.system(size: 14))

                                    HStack(spacing: 10) {
                                        if let company = tweak.company {
                                            HStack(spacing: 4) {
                                                Image(systemName: "building.2.fill")
                                                    .font(.system(size: 16))
                                                Text(company)
                                                    .font(.system(size: 14))
                                            }
                                        }

                                        HStack(spacing: 4) {
                                            Image(systemName: "tag.fill")
                                                .font(.system(size: 14))
                                            Text(tweak.category.uppercased())
                                                .font(.system(size: 12))
                                        }

                                        if let platforms = tweak.platforms {
                                            HStack(spacing: 4) {
                                                Image(systemName: "desktopcomputer")
                                                    .font(.system(size: 14))
                                                Text(platforms.joined(separator: ", "))
                                                    .font(.system(size: 12))
                                            }
                                        }

                                        if let version = tweak.version {
                                            HStack(spacing: 4) {
                                                Image(systemName: "doc.badge.gearshape")
                                                    .font(.system(size: 14))
                                                Text("v\(version)")
                                                    .font(.system(size: 12))
                                            }
                                        }

                                        if let date = tweak.date {
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .font(.system(size: 14))
                                                Text(date)
                                                    .font(.system(size: 12))
                                            }
                                        }
                                        
                                        if let longDesc = tweak.description_long, !longDesc.isEmpty {
                                            Button("Read More") {
                                                print("🔍 Read more for: \(tweak.id)")
                                                selectedTweak = tweak
                                                showDetailModal = true
                                            }
                                            .font(.system(size: 12, weight: .medium))
                                            .buttonStyle(.plain)
                                            .foregroundColor(Color(.darkGray))
                                        }
                                    }
                                }

                                Spacer()

                                if tweak.installed {
                                    Button("🗑️ Uninstall") {
                                        uninstallTweak(tweak)
                                    }
                                } else {
                                    Button("Install") {
                                        installTweak(tweak)
                                    }
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.10)))
                            .onChange(of: settings.selectedRuntime) { _ in
                                loadTweaks()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            loadTweaks()
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $selectedTweak) { tweak in
            VStack(alignment: .leading, spacing: 16) {
                Text(tweak.title)
                    .font(.title2)
                    .bold()

                ScrollView {
                    Text(tweak.description_long ?? "No additional info available.")
                        .font(.body)
                        .padding(.top, 4)
                }

                Spacer()
                HStack {
                    Spacer()
                    Button("Close") {
                        selectedTweak = nil
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding()
            .frame(minWidth: 400, minHeight: 300)
        }
    }

    func loadTweaks() {
        loadingTweaks = true

        let request = URLRequest(url: tweaksPath, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.loadingTweaks = false
                    self.errorMessage = "Failed to load tweaks: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.loadingTweaks = false
                    self.errorMessage = "No data received."
                    self.showErrorAlert = true
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(WineTweakDatabase.self, from: data)

                // Save Cache
                saveToCache(data)

                let installedKeys = UserDefaults.standard.stringArray(forKey: "installedTweaks") ?? []
                let runtime = settings.selectedRuntime

                let withStatus = decoded.tweaks.map { tweak -> WineTweak in
                    var t = tweak
                    if let bottle = appState.selectedBottle {
                        let key = "\(tweak.id)@\(runtime.rawValue)@\(bottle.path.path)"
                        t.installed = installedKeys.contains(key)
                    }
                    return t
                }

                DispatchQueue.main.async {
                    self.tweaks = withStatus
                    self.loadingTweaks = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingTweaks = false
                    self.errorMessage = "Failed to decode tweaks: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    loadFromCacheIfAvailable()
                }
            }
        }.resume()
    }

    func saveToCache(_ data: Data) {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("cachedTweaks.json")

        try? data.write(to: cacheURL)
    }
    
    func loadFromCacheIfAvailable() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("cachedTweaks.json")

        guard let data = try? Data(contentsOf: cacheURL) else {
            #if DEBUG
            print("❌ No cached data found at \(cacheURL.path)")
            #endif

            DispatchQueue.main.async {
                self.errorMessage = "No cached tweaks found. Please check your internet connection."
                self.showErrorAlert = true
            }
            return
        }

        do {
            let decoded = try JSONDecoder().decode(WineTweakDatabase.self, from: data)
            let installedKeys = UserDefaults.standard.stringArray(forKey: "installedTweaks") ?? []
            let runtime = settings.selectedRuntime

            let withStatus = decoded.tweaks.map { tweak -> WineTweak in
                var t = tweak
                if let bottle = appState.selectedBottle {
                    let key = "\(tweak.id)@\(runtime.rawValue)@\(bottle.path.path)"
                    t.installed = installedKeys.contains(key)
                }
                return t
            }

            DispatchQueue.main.async {
                self.tweaks = withStatus
            }

        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load tweaks from cache."
                self.showErrorAlert = true
            }

            #if DEBUG
            print("❌ Failed to decode cached data: \(error.localizedDescription)")
            #endif
        }
    }

    func installTweak(_ tweak: WineTweak) {
        guard let bottle = appState.selectedBottle else {
            #if DEBUG
            print("❌ No bottle selected")
            #endif
            return
        }

        #if DEBUG
        print("🧪 Installing tweak \(tweak.title) into: \(bottle.path.path)")
        #endif

        TweakExecutor.apply(tweak, to: bottle, using: settings) { error in
            errorMessage = error
            showErrorAlert = true
            #if DEBUG
            print("❌ Tweak install failed: \(error)")
            #endif
        } onFinish: {
            markTweakAsInstalled(tweak.id)
            loadTweaks()
            #if DEBUG
            print("✅ Tweak \(tweak.title) installed successfully")
            #endif
        }
    }
    
    func uninstallTweak(_ tweak: WineTweak) {
        let runtime = settings.selectedRuntime
        guard let bottle = appState.selectedBottle else { return }

        let key = "\(tweak.id)@\(runtime.rawValue)@\(bottle.path.path)"

        TweakExecutor.uninstall(tweak, from: bottle, using: settings) { error in
            errorMessage = error
            showErrorAlert = true
        } onFinish: {
            var installed = UserDefaults.standard.stringArray(forKey: "installedTweaks") ?? []
            installed.removeAll { $0 == key }
            UserDefaults.standard.set(installed, forKey: "installedTweaks")
            loadTweaks()
            #if DEBUG
            print("🗑️ Tweak \(tweak.title) uninstalled (\(key))")
            #endif
        }
    }

    func tweakKey(for tweak: WineTweak) -> String? {
        guard let bottle = appState.selectedBottle else { return nil }
        let runtime = settings.selectedRuntime
        return "\(tweak.id)@\(runtime.rawValue)_\(bottle.name)"
    }
    
    func markTweakAsInstalled(_ id: String) {
        let runtime = settings.selectedRuntime
        guard let bottle = appState.selectedBottle else { return }

        let key = "\(id)@\(runtime.rawValue)@\(bottle.path.path)"  // ✅ runtime + bottle path
        var installed = UserDefaults.standard.stringArray(forKey: "installedTweaks") ?? []

        if !installed.contains(key) {
            installed.append(key)
            UserDefaults.standard.set(installed, forKey: "installedTweaks")
            #if DEBUG
            print("✅ Marked as installed: \(key)")
            #endif
        }
    }
    
    func clearBottleCache(_ bottle: Bottle) {
        let bottlePath = bottle.path.path
        var installed = UserDefaults.standard.stringArray(forKey: "installedTweaks") ?? []
        installed.removeAll(where: { $0.contains(bottlePath) })
        UserDefaults.standard.set(installed, forKey: "installedTweaks")
        #if DEBUG
        print("🧹 Cleared cache for bottle at path: \(bottlePath)")
        #endif
    }
}
