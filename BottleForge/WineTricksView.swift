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

struct ClassicTweak: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let dlls: [String]?
    let depends: [String]?
    let arch: String?

    var installed: Bool = false
}

enum WineTricksMode: String, CaseIterable, Identifiable {
    case macOS, classic
    var id: String { rawValue }

    var title: String {
        switch self {
        case .macOS: return "🍷 macOS Winetricks"
        case .classic: return "📦 Classic Winetricks"
        }
    }
}

enum UnifiedTweak: Identifiable {
    case mac(WineTweak)
    case classic(ClassicTweak)

    var id: String {
        switch self {
        case .mac(let t): return t.id
        case .classic(let t): return t.id
        }
    }

    var title: String {
        switch self {
        case .mac(let t): return t.title
        case .classic(let t): return t.name
        }
    }

    var description: String {
        switch self {
        case .mac(let t): return t.description
        case .classic: return "No description available."
        }
    }

    var installed: Bool {
        switch self {
        case .mac(let t): return t.installed
        case .classic: return false
        }
    }
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
    @State private var selectedMode: WineTricksMode = .macOS
    @State private var unifiedTweaks: [UnifiedTweak] = []
    @State private var installingTweakID: String? = nil
    @State private var tweakLog: String = ""
    @State private var showLogPanel = false

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
    
    var filteredUnifiedTweaks: [UnifiedTweak] {
        if filter.isEmpty { return unifiedTweaks }

        let lowerFilter = filter.lowercased()
        return unifiedTweaks.filter { tweak in
            tweak.title.lowercased().contains(lowerFilter) ||
            tweak.description.lowercased().contains(lowerFilter)
        }
    }

    var tweakLogLines: [String] {
        let lines = tweakLog.components(separatedBy: .newlines)
        return Array(lines.suffix(1000))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Mode", selection: $selectedMode) {
                ForEach(WineTricksMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }.pickerStyle(.segmented)
            
            Text(selectedMode == .macOS ?
                 "🍷 Winetricks macOS" :
                 "📦 Classic Winetricks")
            .font(.title)

            Text(selectedMode == .macOS ?
                 "Custom Winetricks-style tweaks tailored for macOS with support for CrossOver and CXPatcher." :
                 "Classic winetricks support using original shell scripts from upstream.")
                .font(.system(size: 14))

            Divider()

            HStack {
                TextField("Search tweak...", text: $filter)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()
                Button("🧹 Clear Cache for This Bottle") {
                    if let bottle = appState.selectedBottle {
                        clearBottleCache(bottle)
                        switch selectedMode {
                        case .macOS: loadTweaks()
                        case .classic: loadClassicTweaks()
                        }
                    }
                }
                .foregroundColor(.red)
            }
            .padding(.bottom)
            
            VStack{
                if(selectedMode != .macOS)
                {
                    Text("⚠️ Some components are Linux-specific and may not behave as expected on macOS. Use with caution – tweaks are not always uninstallable and may require manual removal. Proceed only if you know what you're doing.").font(.system(size: 14))
                    if showLogPanel {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(tweakLogLines.indices, id: \.self) { idx in
                                        Text(tweakLogLines[idx])
                                            .font(.system(size: 12, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    Color.clear.frame(height: 1).id("BOTTOM")
                                }
                                .padding()
                            }
                            .frame(height: 200)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                            .padding(.top, 8)
                        }
                    }
                    
                    Button(action: { showLogPanel.toggle() }) {
                        Text(showLogPanel ? "Hide Log" : "Show Log")
                    }
                }
            }

            if loadingTweaks {
                ProgressView("Loading tweaks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if selectedMode == .macOS {
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
                                       if installingTweakID == tweak.id {
                                           ProgressView()
                                               .progressViewStyle(CircularProgressViewStyle())
                                       } else {
                                           Button("🗑️ Uninstall") {
                                               installingTweakID = tweak.id
                                               uninstallTweak(tweak)
                                           }
                                       }
                                    } else {
                                        if installingTweakID == tweak.id {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                        } else {
                                            Button("Install") {
                                                installingTweakID = tweak.id
                                                installTweak(tweak)
                                            }
                                        }
                                    }
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.10)))
                                // Runtime change handling moved to container-level
                            }
                        } else {
                            ForEach(filteredUnifiedTweaks) { tweak in
                                if case .classic(let ct) = tweak {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ct.name)
                                                .font(.system(size: 16, weight: .semibold))
                                        }

                                        Spacer()

                                        if let bottle = appState.selectedBottle {
                                            if installingTweakID == ct.id {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle())
                                            } else {
                                                Button("Install") {
                                                    installingTweakID = ct.id
                                                    
                                                    //clear log
                                                    tweakLog = ""
                                                    
                                                    runClassicTweakInstall(ct, bottle: bottle, onFinish: {
                                                        installingTweakID = nil
                                                    }, onError: { _ in
                                                        installingTweakID = nil
                                                    }, onLog: { line in
                                                        tweakLog += line
                                                    })
                                                }
                                            }
                                        } else {
                                            Text("No bottle selected")
                                                .foregroundColor(.red)
                                                .font(.system(size: 12))
                                        }
                                    }
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.10)))
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onChange(of: selectedMode) { newMode in
            switch newMode {
            case .macOS: loadTweaks()
            case .classic: loadClassicTweaks()
            }
        }
        // Reload tweaks when runtime changes, after view updates commit
        .task(id: settings.selectedRuntime) {
            switch selectedMode {
            case .macOS: loadTweaks()
            case .classic: loadClassicTweaks()
            }
        }
        // Initial load
        .onAppear {
            switch selectedMode {
            case .macOS: loadTweaks()
            case .classic: loadClassicTweaks()
            }
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
        DispatchQueue.main.async { self.loadingTweaks = true }

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

                let unified = decoded.tweaks.map { tweak -> UnifiedTweak in
                    var t = tweak
                    if let bottle = appState.selectedBottle {
                        let key = "\(t.id)@\(runtime.rawValue)@\(bottle.path.path)"
                        t.installed = installedKeys.contains(key)
                    }
                    return .mac(t)
                }

                DispatchQueue.main.async {
                    self.tweaks = withStatus
                    self.unifiedTweaks = unified
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
    
    // MARK: - Classic Winetricks installation handler
    func runClassicTweakInstall(
        _ tweak: ClassicTweak,
        bottle: Bottle,
        onFinish: @escaping () -> Void = {},
        onError: @escaping (String) -> Void = { _ in },
        onLog: @escaping (String) -> Void = { _ in }
    ) {
        ClassicTweakExecutor.install(
            tweak,
            to: bottle,
            using: settings,
            onError: { error in
                errorMessage = error
                showErrorAlert = true
                onError(error)
            },
            onFinish: {
                loadClassicTweaks()

                // MARK: - Success handler (classic tweak install complete)
                let alert = NSAlert()
                alert.messageText = "Tweak installed"
                alert.informativeText = "✅ The tweak \"\(tweak.name)\" was successfully installed."
                alert.addButton(withTitle: "OK")
                alert.runModal()

                onFinish()
                
                // MARK: - Cleanup cache after tweak installation
                let cachePath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".cache/winetricks")

                do {
                    if FileManager.default.fileExists(atPath: cachePath.path) {
                        try FileManager.default.removeItem(at: cachePath)
                        #if DEBUG
                        print("🧹 Winetricks cache deleted: \(cachePath.path)")
                        #endif
                    }
                } catch {
                    errorMessage = "Failed to delete Winetricks cache: \(error.localizedDescription)"
                    showErrorAlert = true
                    #if DEBUG
                    print("❌ \(errorMessage)")
                    #endif
                }
            },
            onLog: onLog
        )
    }

    // MARK: - Classic tweaks loading + parsing
    func loadClassicTweaks() {
        DispatchQueue.main.async { self.loadingTweaks = true }

        let url = URL(string: "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks")!
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { DispatchQueue.main.async { loadingTweaks = false } }

            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load classic winetricks script."
                    self.showErrorAlert = true
                }
                return
            }

            let parsed = parseClassicTweaks(from: content)

            // Get Info to check installation
            let runtime = settings.selectedRuntime
            let bottlePath = appState.selectedBottle?.path.path ?? ""
            let installedKeys = UserDefaults.standard.stringArray(forKey: "installedClassicTweaks") ?? []

            // Remove duplicity + assign status
            var seen = Set<String>()
            let tweaksWithStatus = parsed.filter {
                !$0.id.isEmpty &&
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                seen.insert($0.id).inserted
            }.map { tweak -> ClassicTweak in
                var t = tweak
                let key = "classic:\(t.id)@\(runtime.rawValue)@\(bottlePath)"
                t.installed = installedKeys.contains(key)
                return t
            }

            DispatchQueue.main.async {
                self.unifiedTweaks = tweaksWithStatus.map { .classic($0) }
            }

        }.resume()
    }
    
    // MARK: - Regex parsing of classic winetricks script
    func parseClassicTweaks(from script: String) -> [ClassicTweak] {
        let pattern = #"(?ms)^load_(\w+)\(\)\s*\{(.*?)^\}"#
        let regex = try! NSRegularExpression(pattern: pattern)

        var tweaks: [ClassicTweak] = []

        let nsrange = NSRange(script.startIndex..<script.endIndex, in: script)
        regex.enumerateMatches(in: script, options: [], range: nsrange) { match, _, _ in
            guard let match = match,
                  let idRange = Range(match.range(at: 1), in: script),
                  let bodyRange = Range(match.range(at: 2), in: script) else { return }

            let id = String(script[idRange])
            let body = String(script[bodyRange])

            func capture(_ key: String) -> String? {
                let pat = #"\#(key)=\"([^\"]+)\""#
                let subRegex = try! NSRegularExpression(pattern: pat)
                if let m = subRegex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
                   let r = Range(m.range(at: 1), in: body) {
                    return String(body[r])
                }
                return nil
            }

            let name = capture("title") ?? id
            let description = capture("desc")
            let dlls = capture("dlls")?.components(separatedBy: " ")
            let depends = capture("depends")?.components(separatedBy: " ")
            let arch = capture("arch")

            tweaks.append(ClassicTweak(id: id, name: name, description: description, dlls: dlls, depends: depends, arch: arch))
        }

        return tweaks
    }

    // MARK: - macOS tweaks caching (load/save)
    func saveToCache(_ data: Data) {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("cachedTweaks.json")

        try? data.write(to: cacheURL)
    }
    
    // MARK: - macOS tweaks caching (load/save)
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

    // MARK: - macOS Winetricks installation handler
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

        installingTweakID = tweak.id

        TweakExecutor.apply(tweak, to: bottle, using: settings) { error in
            errorMessage = error
            showErrorAlert = true
            installingTweakID = nil
            #if DEBUG
            print("❌ Tweak install failed: \(error)")
            #endif
        } onFinish: {
            markTweakAsInstalled(tweak.id)
            loadTweaks()
            installingTweakID = nil
            #if DEBUG
            print("✅ Tweak \(tweak.title) installed successfully")
            #endif
        }
    }
    
    // MARK: - macOS Winetricks uninstall handler
    func uninstallTweak(_ tweak: WineTweak) {
        installingTweakID = tweak.id
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
            installingTweakID = nil
        }
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
    
    // MARK: - Remove tweak install keys for current bottle
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
