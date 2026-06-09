//
//  BottleConfig.swift
//  BottleForge
//
//  Created by Radim Veselý on 23.09.2025.
//

import SwiftUI
import AppKit

// MARK: - BottleConfigView

struct BottleConfigView: View {
    @ObservedObject var appState: AppState
    @EnvironmentObject var settings: SettingsManager

    @State private var toggles: [EnvToggle] = []
    @State private var editingId: UUID? = nil
    @State private var isDirty = false
    @State private var loadingError: String?
    @State private var infoMessage: String?
    @State private var existingManagedKeys: Set<String> = []
    private let nonEditableKeys: Set<String> = [
        "D3DM_ENABLE_METALFX",
        "ROSETTA_ADVERTISE_AVX",
        "MTL_HUD_ENABLED",
        "D3DM_SUPPORT_DXR",
        "D3DM_MAX_FPS",
        "D3DM_MTL4"
    ]

    private let defaultKeys: [String] = [
        "WINEESYNC",
        "WINEMSYNC",
        "D3DM_ENABLE_METALFX",
        "ROSETTA_ADVERTISE_AVX",
        "MTL_HUD_ENABLED",
        "D3DM_SUPPORT_DXR",
        "D3DM_MAX_FPS",
        "D3DM_MTL4"
    ]

    private let skipKeys: Set<String> = [
        "PROMPT",
        "CX_BOTTLE_CREATOR_APPID"
    ]

    // Quick-add tips
    private struct TipItem: Identifiable, Hashable {
        var id: String { key }
        let key: String
        let description: String
        let defaultValue: String
        let isBoolean: Bool
        let badges: [TipBadge]

        var defaultOn: Bool {
            ["1", "true", "yes", "on"].contains(defaultValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
    }

    private enum TipBadgeStyle: Hashable {
        case macOS
        case macOS26
        case macOS27
        case gptkOlder
        case gptk3
        case gptk4
    }

    private struct TipBadge: Identifiable, Hashable {
        var id: String { text }
        let text: String
        let systemImage: String
        let style: TipBadgeStyle
    }

    private let tips: [TipItem] = [
        TipItem(
            key: "MTL_HUD_ENABLED",
            description: "Metal HUD – GPU-only overlay with FPS and basic GPU metrics.",
            defaultValue: "0",
            isBoolean: true,
            badges: [
                TipBadge(text: "Older GPTK", systemImage: "clock.arrow.circlepath", style: .gptkOlder),
                TipBadge(text: "GPTK 3", systemImage: "gamecontroller.fill", style: .gptk3),
                TipBadge(text: "GPTK 4", systemImage: "gamecontroller.fill", style: .gptk4)
            ]
        ),
        TipItem(
            key: "ROSETTA_ADVERTISE_AVX",
            description: "Makes Rosetta advertise AVX CPU capability to translated apps. It does not add new Rosetta instructions; it only changes what the app sees when it checks CPU features.",
            defaultValue: "0",
            isBoolean: true,
            badges: [
                TipBadge(text: "macOS 15+", systemImage: "apple.logo", style: .macOS),
                TipBadge(text: "GPTK 3", systemImage: "gamecontroller.fill", style: .gptk3),
                TipBadge(text: "GPTK 4", systemImage: "gamecontroller.fill", style: .gptk4)
            ]
        ),
        TipItem(
            key: "D3DM_ENABLE_METALFX",
            description: "Converts supported DLSS calls to MetalFX where possible. Useful for games that expose DLSS, but support depends on the game and the evaluation environment.",
            defaultValue: "1",
            isBoolean: true,
            badges: [
                TipBadge(text: "macOS 26 Tahoe", systemImage: "apple.logo", style: .macOS26),
                TipBadge(text: "GPTK 3", systemImage: "gamecontroller.fill", style: .gptk3),
                TipBadge(text: "GPTK 4", systemImage: "gamecontroller.fill", style: .gptk4)
            ]
        ),
        TipItem(
            key: "D3DM_SUPPORT_DXR",
            description: "Enables DirectX Raytracing support in D3DMetal’s DirectX 12 layer, so games that check for DXR can see the expected support and interfaces. Defaults OFF on M1/M2 and ON on M3 or newer.",
            defaultValue: "0",
            isBoolean: true,
            badges: [
                TipBadge(text: "GPTK 3", systemImage: "gamecontroller.fill", style: .gptk3),
                TipBadge(text: "GPTK 4", systemImage: "gamecontroller.fill", style: .gptk4)
            ]
        ),
        TipItem(
            key: "D3DM_MAX_FPS",
            description: "Caps the game or app to a chosen frame rate. The default quick-add value is 60 FPS, but you can edit it after adding the variable.",
            defaultValue: "60",
            isBoolean: false,
            badges: [
                TipBadge(text: "GPTK 4", systemImage: "gamecontroller.fill", style: .gptk4)
            ]
        ),
        TipItem(
            key: "D3DM_MTL4",
            description: "Enables the Metal 4 backend for D3DMetal’s DirectX 12 layer. Turn it OFF to keep using the default backend.",
            defaultValue: "1",
            isBoolean: true,
            badges: [
                TipBadge(text: "Only for macOS 27", systemImage: "apple.logo", style: .macOS27),
                TipBadge(text: "GPTK 4", systemImage: "gamecontroller.fill", style: .gptk4)
            ]
        )
    ]

    private struct RequirementBadge: View {
        let badge: TipBadge

        private var tint: Color {
            switch badge.style {
            case .macOS:
                return .purple
            case .macOS26:
                return .orange
            case .macOS27:
                return Color(red: 0.24, green: 0.62, blue: 0.95)
            case .gptkOlder:
                return .secondary
            case .gptk3:
                return .red
            case .gptk4:
                return .green
            }
        }

        var body: some View {
            Label(badge.text, systemImage: badge.systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(tint.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(tint.opacity(0.28), lineWidth: 1)
                        )
                )
        }
    }

    private func addTip(_ tip: TipItem) {
        // Do not duplicate if already present in file; if toggle exists, just set default state
        if let idx = toggles.firstIndex(where: { $0.key == tip.key }) {
            toggles[idx].isBoolean = tip.isBoolean
            toggles[idx].isOn = tip.defaultOn
            toggles[idx].value = tip.defaultValue
            if !nonEditableKeys.contains(tip.key) {
                editingId = toggles[idx].id
            }
        } else {
            let new = EnvToggle(key: tip.key, isOn: tip.defaultOn, isBoolean: tip.isBoolean, value: tip.defaultValue)
            toggles.append(new)
            if !nonEditableKeys.contains(tip.key) {
                editingId = new.id
            }
        }
        existingManagedKeys.insert(tip.key)
        isDirty = true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Bottle Config", systemImage: "slider.horizontal.3")
                Text("Check if required dependencies are installed on your macOS system.")
                    .font(.system(size: 14))
                Divider()

                HStack {
                    Text("Bottle Config – Environment Variables")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button("Reload") { load() }
                        .keyboardShortcut("r", modifiers: [.command])
                    Button("Save") { save() }
                        .keyboardShortcut("s", modifiers: [.command])
                        .disabled(!isDirty || appState.selectedBottle == nil)
                }

                if let err = loadingError {
                    Text("\(err)").foregroundColor(.red)
                }
                if let msg = infoMessage {
                    Text(msg).foregroundColor(.secondary)
                }

                if let bottle = appState.selectedBottle {
                    Text("Selected bottle: \(bottle.name)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    ToggleListView(toggles: $toggles, editingId: $editingId, nonEditableKeys: nonEditableKeys) {
                        isDirty = true
                    }

                    HStack {
                        Button("Add variable") {
                            let new = EnvToggle(key: "NEW_VARIABLE", isOn: false, isBoolean: false, value: "")
                            toggles.append(new)
                            editingId = new.id
                            isDirty = true
                        }
                        .disabled(appState.selectedBottle == nil)

                        Spacer()
                    }

                    GroupBox("Tips – Quick Add") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(tips) { tip in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tip.key)
                                            .font(.system(size: 13, weight: .semibold))
                                        if !tip.badges.isEmpty {
                                            HStack(spacing: 6) {
                                                ForEach(tip.badges) { badge in
                                                    RequirementBadge(badge: badge)
                                                }
                                            }
                                        }
                                        Text(tip.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .layoutPriority(1)
                                    }
                                    Spacer()
                                    if !toggles.contains(where: { $0.key == tip.key }) {
                                        Button("Add") { addTip(tip) }
                                    }
                                }
                                if tip.key != tips.last?.key { Divider() }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                } else {
                    Text("No bottle selected.").foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.trailing, 8)
        }
        .onAppear { load() }
    }

    // MARK: Load / Save

    private func load() {
        loadingError = nil
        infoMessage = nil
        isDirty = false
        guard let bottle = appState.selectedBottle else { return }
        do {
            let url = try configURL(for: bottle)
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let envMap = parseEnvironmentVariables(from: text)

            // Track keys already present in file so quick-add does not duplicate them.
            var present: Set<String> = []
            for (k, _) in envMap {
                if skipKeys.contains(k) { continue }
                present.insert(k)
            }
            existingManagedKeys = present

            var newToggles: [EnvToggle] = []
            for k in envMap.keys.sorted() {
                if skipKeys.contains(k) { continue }
                let raw = envMap[k]!
                let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isBoolLike = ["0","1","true","false","yes","no","on","off"].contains(lowered)
                let on = normalizeBool(raw)
                newToggles.append(EnvToggle(key: k, isOn: on, isBoolean: isBoolLike, value: raw))
            }
            toggles = newToggles
            isDirty = false
            infoMessage = "Loaded \(toggles.count) variables from cxbottle.conf"
        } catch {
            loadingError = error.localizedDescription
        }
    }

    private func save() {
        loadingError = nil
        infoMessage = nil
        guard let bottle = appState.selectedBottle else { return }
        normalizeTogglePresentation()

        // Helper for simple checksum (not cryptographic)
        func sha1(_ s: String) -> String {
            // simple poor-man hash (not crypto) to avoid importing CryptoKit
            return String(s.hashValue)
        }

        do {
            let url = try configURL(for: bottle)
            let fm = FileManager.default

            var text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

            // Compute hash before change
            let beforeHash = sha1(text)

            // Ensure section exists
            if findEnvironmentSection(in: text) == nil {
                let banner = Self.environmentBanner
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text = banner + "\n"
                } else {
                    text += "\n\n" + banner + "\n"
                }
            }

            // Upsert variables
            text = upsertEnvironmentVariables(in: text, values: togglesDict())

            // Compute hash after change
            let afterHash = sha1(text)
            if beforeHash == afterHash {
                infoMessage = "No changes to write (content identical)."
            } else {
                infoMessage = "Config updated."
            }

            // Backup
            if fm.fileExists(atPath: url.path) {
                let backup = url.deletingLastPathComponent().appendingPathComponent("cxbottle.conf.bak")
                try? fm.removeItem(at: backup)
                try fm.copyItem(at: url, to: backup)
            }

            try text.write(to: url, atomically: true, encoding: .utf8)
            existingManagedKeys = Set(toggles.map { $0.key })
            isDirty = false
            infoMessage = "Saved: \(url.path)"
        } catch {
            loadingError = error.localizedDescription
        }
    }

    private func togglesDict() -> [String: String] {
        var dict: [String: String] = [:]
        for t in toggles {
            let key = t.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            dict[key] = t.isBoolean ? (t.isOn ? "1" : "0") : t.value
        }
        return dict
    }

    private func normalizeTogglePresentation() {
        for idx in toggles.indices {
            toggles[idx].normalizePresentation()
        }
    }

    // MARK: File helpers

    private func configURL(for bottle: Bottle) throws -> URL {
        // Both CrossOver and CXPatcher bottles store cxbottle.conf at the bottle root
        let url = bottle.path.appendingPathComponent("cxbottle.conf")
        if !FileManager.default.fileExists(atPath: url.path) {
            // If it does not exist, create an empty file so we can populate the banner/section
            try "".write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    // Parses values in the [EnvironmentVariables] section in the format
    //   "NAME" = "value"
    private func parseEnvironmentVariables(from text: String) -> [String: String] {
        guard let range = findEnvironmentSection(in: text) else { return [:] }
        let section = String(text[range])
        var result: [String: String] = [:]
        // regex for lines like: "VAR" = "1"
        let pattern = "^\\s*\"([^\"]+)\"\\s*=\\s*\"([^\"]*)\"\\s*$"
        if let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
            let ns = section as NSString
            let matches = re.matches(in: section, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                if m.numberOfRanges == 3 {
                    let key = ns.substring(with: m.range(at: 1))
                    let val = ns.substring(with: m.range(at: 2))
                    result[key] = val
                }
            }
        }
        return result
    }

    private func normalizeBool(_ raw: String) -> Bool {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["1", "true", "yes", "on"].contains(v)
    }

    private func findEnvironmentSection(in text: String) -> Range<String.Index>? {
        guard let start = text.range(of: "[EnvironmentVariables]") else { return nil }
        // section ends at next [Header] or end of file
        let remainder = text[start.upperBound...]
        // Find the next header start by looking for a newline followed by '['
        if let nextHeader = remainder.range(of: "\n[") {
            return start.lowerBound..<nextHeader.lowerBound
        }
        return start.lowerBound..<text.endIndex
    }

    private func upsertEnvironmentVariables(in text: String, values: [String: String]) -> String {
        guard let sectionRange = findEnvironmentSection(in: text) else { return text }

        let prefix = String(text[..<sectionRange.lowerBound])
        let section = String(text[sectionRange])
        let suffix = String(text[sectionRange.upperBound...])

        // Split section into lines and normalize whitespace
        var lines = section.components(separatedBy: "\n")
        lines = lines.map { $0.trimmingCharacters(in: .whitespaces) }

        // Split header (up to and including the [EnvironmentVariables] line)
        let headerIndex = lines.firstIndex(where: { $0.contains("[EnvironmentVariables]") }) ?? 0
        var headerLines = Array(lines.prefix(headerIndex + 1))
        headerLines.removeAll { $0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Body lines after header
        let bodyLines = Array(lines.dropFirst(headerIndex + 1))

        // Regex to parse any key line (captures optional leading ';', key, value)
        let parsePattern = "^\\s*(;*)\\s*\"([^\"]+)\"\\s*=\\s*\"([^\"]*)\"\\s*$"
        let parseRe = try? NSRegularExpression(pattern: parsePattern, options: [])

        // 1) Preserve non-managed keys with de-duplication (including commented variants)
        //    Prefer an active (non-commented) occurrence; otherwise keep one commented.
        var keptForKey: [String: (line: String, isCommented: Bool)] = [:]
        var order: [String] = [] // to preserve first-seen order

        func isManaged(_ key: String) -> Bool { return values[key] != nil }
        func wasManagedBefore(_ key: String) -> Bool {
            // Keys we control via the UI: either known defaults or previously detected in the section.
            // Never treat skipKeys as managed for deletion
            return (existingManagedKeys.contains(key) || defaultKeys.contains(key)) && !skipKeys.contains(key)
        }

        for line in bodyLines {
            guard let re = parseRe else { continue }
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let m = re.firstMatch(in: line, options: [], range: range) {
                let semis = ns.substring(with: m.range(at: 1))
                let key   = ns.substring(with: m.range(at: 2))
                // let val = ns.substring(with: m.range(at: 3)) // value not needed for dedupe
                let isCommented = !semis.isEmpty

                if isManaged(key) {
                    // Skip: managed keys will be re-appended from `values`
                    continue
                }

                // If the key used to be managed (boolean-like) but is now removed from toggles,
                // drop it entirely from the file by not preserving this line.
                if wasManagedBefore(key) {
                    continue
                }

                if let existing = keptForKey[key] {
                    // If we already kept a commented one and now see an active, replace it
                    if existing.isCommented && !isCommented {
                        keptForKey[key] = (line: "\"\(key)\" = \"\(ns.substring(with: m.range(at: 3)))\"", isCommented: false)
                    }
                    // else: keep existing (either both commented, or both active — keep first)
                } else {
                    keptForKey[key] = (line: isCommented ? "\"\(key)\" = \"\(ns.substring(with: m.range(at: 3)))\"" : "\"\(key)\" = \"\(ns.substring(with: m.range(at: 3)))\"", isCommented: isCommented)
                    order.append(key)
                }
            } else {
                // Non key-value line in body: drop empty, keep others as-is
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    let k = "__raw__\(order.count)"
                    keptForKey[k] = (line: line, isCommented: false)
                    order.append(k)
                }
            }
        }

        // Build preserved lines in original discovery order
        let preservedLines: [String] = order.compactMap { key in
            if let item = keptForKey[key] {
                return item.line
            }
            return nil
        }

        // 2) Append managed keys in deterministic order
        let defaultOrder = defaultKeys.filter { values[$0] != nil }
        let remaining = values.keys.filter { !defaultOrder.contains($0) }.sorted()
        let orderedKeys = defaultOrder + remaining

        var keyLines: [String] = []
        for key in orderedKeys {
            if let val = values[key] {
                keyLines.append("\"\(key)\" = \"\(val)\"")
            }
        }

        // Assemble new section
        var newLines = headerLines
        newLines.append(contentsOf: preservedLines)
        newLines.append(contentsOf: keyLines)

        var newSection = newLines.joined(separator: "\n")
        if !newSection.hasSuffix("\n") { newSection += "\n" }

        var newText = prefix + newSection + suffix

        // 3) Collapse multiple blank lines into a single newline across the whole file
        if let re = try? NSRegularExpression(pattern: "(\n){2,}", options: []) {
            let ns = newText as NSString
            let range = NSRange(location: 0, length: ns.length)
            newText = re.stringByReplacingMatches(in: newText, options: [], range: range, withTemplate: "\n")
        }

        return newText
    }

    static let environmentBanner: String = {
        return """
        ;;---------------< User defined environment variables >-----------------
        ;; Add environment variables that need to be defined in the
        ;; Wine environment here. They should be in the form:
        ;;
        ;; \"VARIABLE\" = \"value\"
        ;;
        ;;----------------------------------------------------------------------
        [EnvironmentVariables]
        """.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
}

// MARK: - EnvToggle & ToggleListView

struct EnvToggle: Identifiable, Hashable {
    let id: UUID = UUID()
    var key: String
    var isOn: Bool
    var isBoolean: Bool
    var value: String

    mutating func normalizePresentation() {
        guard !isBoolean else { return }

        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = normalizedValue.lowercased()
        value = normalizedValue

        if ["0", "1", "true", "false", "yes", "no", "on", "off"].contains(lowered) {
            isBoolean = true
            isOn = ["1", "true", "yes", "on"].contains(lowered)
        }
    }
}

struct ToggleListView: View {
    @Binding var toggles: [EnvToggle]
    @Binding var editingId: UUID?
    let nonEditableKeys: Set<String>
    var onChange: () -> Void
    @FocusState private var focusedId: UUID?
    @FocusState private var focusedValueId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(toggles.indices, id: \.self) { idx in
                let binding = $toggles[idx]
                let t = toggles[idx]
                HStack(alignment: .center, spacing: 12) {
                    Group {
                        if t.isBoolean {
                            Toggle(isOn: binding.isOn) {
                                keyEditor(binding: binding, toggle: t)
                            }
                            .toggleStyle(CheckboxToggleStyle())
                        } else {
                            keyEditor(binding: binding, toggle: t)
                        }
                    }

                    if !t.isBoolean {
                        TextField("Value", text: binding.value)
                            .font(.system(size: 13))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                            .focused($focusedValueId, equals: t.id)
                            .onSubmit {
                                toggles[idx].normalizePresentation()
                                focusedValueId = nil
                                onChange()
                            }
                    }

                    Spacer()

                    Button(role: .destructive) {
                        toggles.remove(at: idx)
                        onChange()
                    } label: {
                        Text("Remove")
                    }
                    .foregroundColor(.red)
                }
                .onChange(of: toggles[idx].isOn) { _ in onChange() }
                .onChange(of: toggles[idx].key) { _ in onChange() }
                .onChange(of: toggles[idx].value) { _ in onChange() }
                Divider()
            }
        }
        .onChange(of: editingId) { new in
            focusedId = new
        }
    }

    @ViewBuilder
    private func keyEditor(binding: Binding<EnvToggle>, toggle: EnvToggle) -> some View {
        Group {
            if editingId == toggle.id {
                TextField("ENV_VAR", text: binding.key)
                    .font(.system(size: 13))
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedId, equals: toggle.id)
                    .onSubmit {
                        editingId = nil
                        onChange()
                    }
            } else {
                Text(toggle.key)
                    .font(.system(size: 13))
                    .onTapGesture(count: 2) {
                        guard !nonEditableKeys.contains(toggle.key) else { return }
                        editingId = toggle.id
                        focusedId = toggle.id
                    }
            }
        }
    }
}

// MARK: - GameConfigView

struct GameConfigView: View {
    @ObservedObject var appState: AppState

    enum GameEngine: String, CaseIterable, Identifiable {
        case unreal = "Unreal Engine"
        case cryEngine = "CryEngine"

        var id: String { rawValue }
    }

    enum ConfigPreset: String, CaseIterable, Identifiable {
        case compatibility = "Compatibility"
        case performance = "Performance"

        var id: String { rawValue }
    }

    @State private var engine: GameEngine = .unreal
    @State private var preset: ConfigPreset = .compatibility

    @State private var useAutoResolution = true
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var disableVsync = true
    @State private var forceBorderless = true
    @State private var includeComments = true

    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Game Config", systemImage: "gamecontroller")
            Text("Generate and export one config file directly from UI. No long shell commands needed.")
                .font(.system(size: 14))
            Divider()

            if let bottle = appState.selectedBottle {
                Text("Selected bottle: \(bottle.name)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            GroupBox("Engine + Preset") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Engine", selection: $engine) {
                        ForEach(GameEngine.allCases) { e in
                            Text(e.rawValue).tag(e)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Preset", selection: $preset) {
                        ForEach(ConfigPreset.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 6)
            }

            GroupBox("Display") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Auto-detect monitor resolution", isOn: $useAutoResolution)

                    HStack {
                        TextField("Width", text: $widthText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .disabled(useAutoResolution)
                        Text("x")
                        TextField("Height", text: $heightText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .disabled(useAutoResolution)
                        Button("Detect") { applyDetectedResolution() }
                    }
                }
                .padding(.horizontal, 6)
            }

            GroupBox("Tweaks") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Disable VSync", isOn: $disableVsync)
                    Toggle("Force borderless/windowed fullscreen", isOn: $forceBorderless)
                    Toggle("Write comments into generated files", isOn: $includeComments)
                }
                .padding(.horizontal, 6)
            }

            HStack {
                Button("Export Config...") { exportConfigFile() }
            }

            if let err = errorMessage {
                Text(err).foregroundColor(.red)
            }
            if let msg = statusMessage {
                Text(msg)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(msg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }

            GroupBox("Notes") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("General")
                        .font(.system(size: 12, weight: .semibold))
                    Text("• Export creates one portable file: autoexec.cfg (CryEngine) or Engine.ini (Unreal).")
                    Text("• Some games ignore custom configs or rewrite values at runtime.")

                    Text("Unreal Engine")
                        .font(.system(size: 12, weight: .semibold))
                    Text("• Some games also use GameUserSettings.ini. Copy relevant lines there when needed.")
                    Text("• Risky Unreal overrides are included as commented lines (;). Enable only per game testing.")
                    Text("• If needed, set read-only manually after export: chmod 444 <file>")

                    Text("CryEngine")
                        .font(.system(size: 12, weight: .semibold))
                    Text("• autoexec.cfg usually works as portable override, but final load order is game-specific.")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            applyDetectedResolution()
        }
    }

    private func applyDetectedResolution() {
        guard let res = detectPrimaryResolution() else { return }
        widthText = "\(res.width)"
        heightText = "\(res.height)"
    }

    private func detectPrimaryResolution() -> (width: Int, height: Int)? {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return nil }
        let frame = screen.frame
        let scale = screen.backingScaleFactor
        let width = max(1, Int((frame.width * scale).rounded()))
        let height = max(1, Int((frame.height * scale).rounded()))
        return (width, height)
    }

    private func resolvedResolution() -> (Int, Int)? {
        if useAutoResolution, let auto = detectPrimaryResolution() {
            return (auto.width, auto.height)
        }

        guard let w = Int(widthText), let h = Int(heightText), w > 0, h > 0 else {
            return nil
        }
        return (w, h)
    }

    private func exportConfigFile() {
        errorMessage = nil
        statusMessage = nil

        guard let (width, height) = resolvedResolution() else {
            errorMessage = "Resolution is invalid."
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Export game config"
        savePanel.prompt = "Export"
        savePanel.nameFieldStringValue = engine == .cryEngine ? "autoexec.cfg" : "Engine.ini"
        let desktopDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
        if FileManager.default.fileExists(atPath: desktopDirectory.path) {
            savePanel.directoryURL = desktopDirectory
        }
        do {
            if savePanel.runModal() != .OK || savePanel.url == nil {
                statusMessage = "Export canceled."
                return
            }

            let targetURL = savePanel.url!
            let content = buildPortableExportContent(width: width, height: height)
            try writeExportFile(url: targetURL, content: content)
            statusMessage = "Exported: \(targetURL.path)"
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func buildPortableExportContent(width: Int, height: Int) -> String {
        let vsyncValue = disableVsync ? 0 : 1
        let vsyncBool = disableVsync ? "False" : "True"
        let fullscreenMode = forceBorderless ? 1 : 0

        switch engine {
        case .cryEngine:
            return buildCryEngineBody(width: width, height: height, vsyncValue: vsyncValue) + "\n"
        case .unreal:
            let header = includeComments ? "; Generated by BottleForge for manual import.\n; If needed rename/move this file to game-specific path.\n\n" : ""
            return header + buildUnrealEngineIniBody(vsyncValue: vsyncValue, screenPercentage: screenPercentage(for: preset)) + "\n\n" + buildUnrealGameUserSettingsBody(vsyncBool: vsyncBool, width: width, height: height, fullscreenMode: fullscreenMode) + "\n"
        }
    }

    private func screenPercentage(for preset: ConfigPreset) -> Int {
        switch preset {
        case .compatibility: return 85
        case .performance: return 80
        }
    }

    private func buildUnrealEngineIniBody(vsyncValue: Int, screenPercentage: Int) -> String {
        let engineHeader = includeComments ? "; Generated by BottleForge Game Config\n; Engine: Unreal\n" : ""
        let optionalRiskyBlock = includeComments ? """
        ; === Optional per-game overrides (can break some UE titles) ===
        ; r.FidelityFX.FSR.Enabled=1
        ; r.TemporalAA.Upsampling=1
        ; r.FidelityFX.FSR.QualityMode=2
        ; r.Lumen.DiffuseIndirect.Allow=0
        ; r.Lumen.DiffuseIndirect.AsyncCompute=0
        ; r.LumenScene.Lighting.AsyncCompute=0
        ; r.Lumen.ScreenProbeGather.AsyncCompute=0
        ; r.EnableAsyncComputeVolumetricFog=0
        """ : ""
        return """
        \(engineHeader)[/Script/Engine.RendererSettings]
        ; === Shader stutter fix ===
        r.pso.CreateOnRHIThread=true
        r.PSOPrecaching=1

        ; === Render scale (safe default) ===
        r.VSync=\(vsyncValue)
        r.ScreenPercentage=\(screenPercentage)

        ; === TAA tweaks for better sharpness ===
        r.AntiAliasingMethod=2
        r.TemporalAA.Quality=4
        r.TemporalAA.Algorithm=1
        r.TemporalAACurrentFrameWeight=0.25
        r.TemporalAAFilterSize=0.2
        r.TemporalAASamples=4
        r.Tonemapper.Sharpen=0.6

        ; === Tonemapping ===
        r.Tonemapper.Quality=3
        r.TonemapperGamma=2.2

        ; === Shadows ===
        r.ShadowQuality=2
        r.Shadow.MaxResolution=2048
        r.Shadow.MaxCSMResolution=1024
        r.Shadow.RadiusThreshold=0.05

        ; === Reflections ===
        r.SSR=1
        r.SSR.Quality=1
        r.SSR.Temporal=1
        r.SSR.HalfResSceneColor=1
        r.SSR.MaxRoughness=0.9
        r.ReflectionEnvironment=1

        ; === Ambient Occlusion ===
        r.AmbientOcclusionLevels=1
        r.AmbientOcclusionRadiusScale=0.3
        r.AmbientOcclusionPower=1.2
        r.AmbientOcclusionMaxQuality=1

        ; === Lumen / async defaults (safer across games) ===
        r.Lumen.DiffuseIndirect.Allow=1
        r.Lumen.DiffuseIndirect.AsyncCompute=0
        r.LumenScene.Lighting.AsyncCompute=0
        r.Lumen.ScreenProbeGather.AsyncCompute=0
        r.EnableAsyncComputeVolumetricFog=0

        ; === Disable heavy post-processing ===
        r.FilmGrain=0
        r.BloomQuality=0
        r.LensFlareQuality=0
        r.MotionBlurQuality=0
        r.DefaultFeature.MotionBlur=0

        ; === Textures + detail ===
        r.MipMapLODBias=0
        r.MaxAnisotropy=8
        r.DetailMode=1
        r.Streaming.PoolSize=1024

        ; === View distance + volumetrics ===
        r.ViewDistanceScale=1.2
        r.VolumetricFog=0
        r.VolumetricCloud=1
        r.SkyAtmosphere=1

        \(optionalRiskyBlock)
        """
    }

    private func buildUnrealGameUserSettingsBody(vsyncBool: String, width: Int, height: Int, fullscreenMode: Int) -> String {
        let userHeader = includeComments ? "; Generated by BottleForge Game Config\n; Resolution + display settings\n" : ""
        return """
        \(userHeader)[/Script/Engine.GameUserSettings]
        bUseVSync=\(vsyncBool)
        ResolutionSizeX=\(width)
        ResolutionSizeY=\(height)
        LastUserConfirmedResolutionSizeX=\(width)
        LastUserConfirmedResolutionSizeY=\(height)
        FullscreenMode=\(fullscreenMode)
        LastConfirmedFullscreenMode=\(fullscreenMode)
        PreferredFullscreenMode=\(fullscreenMode)
        Version=5
        """
    }

    private func buildCryEngineBody(width: Int, height: Int, vsyncValue: Int) -> String {
        let maxFps: Int = {
            switch preset {
            case .compatibility: return 120
            case .performance: return 165
            }
        }()

        let fsrQuality: Int = {
            switch preset {
            case .compatibility: return 2
            case .performance: return 3
            }
        }()

        let fsrSharpness: Double = {
            switch preset {
            case .compatibility: return 0.45
            case .performance: return 0.70
            }
        }()

        let globalQuality: Int = {
            switch preset {
            case .compatibility: return 3
            case .performance: return 2
            }
        }()

        let objectQuality: Int = {
            switch preset {
            case .compatibility: return 3
            case .performance: return 2
            }
        }()

        let shadowQuality: Int = {
            switch preset {
            case .compatibility: return 3
            case .performance: return 2
            }
        }()

        let shadowTexRes: Int = {
            switch preset {
            case .compatibility: return 2048
            case .performance: return 1536
            }
        }()

        let shadowPoolSize: Int = {
            switch preset {
            case .compatibility: return 4096
            case .performance: return 3072
            }
        }()

        let postProcessingQuality: Int = {
            switch preset {
            case .compatibility: return 3
            case .performance: return 2
            }
        }()

        func comment(_ text: String) -> String {
            includeComments ? "; \(text)\n" : ""
        }

        return """
        \(comment("========================="))\
        \(comment("CryEngine Apple Silicon Optimized Config"))\
        \(comment("Generated by BottleForge"))\
        \(comment("========================="))\
        \(comment("-------- Console & UI --------"))\
        con_restricted=0
        wh_pl_showfirecursor=1

        \(comment("-------- General / Console --------"))\
        sys_MaxFPS=\(maxFps)
        r_VSync=\(vsyncValue)

        \(comment("-------- Resolution (auto-detected) --------"))\
        r_Width=\(width)
        r_Height=\(height)
        r_Fullscreen=\(forceBorderless ? 0 : 1)

        \(comment("-------- Upscaling / FSR --------"))\
        r_SuperResolution_mode=1
        r_SuperResolution_AMD_FSR_QualityMode=\(fsrQuality)
        r_SuperResolution_AMD_FSR_CustomResolutionScaleWH=1
        r_SuperResolution_Sharpness=\(String(format: "%.2f", fsrSharpness))

        \(comment("-------- CPU / Threads --------"))\
        sys_job_system_max_worker=-1

        \(comment("-------- Memory / Streaming --------"))\
        sys_preload=1
        sys_PakStreamCache=1
        sys_budget_videomem=6144
        sys_budget_sysmem=24576
        r_TexturesStreamingMaxRequestedMB=4096
        r_TexturesStreamPoolSize=4096
        r_texturesstreamingMinUsableMips=1
        r_texturesstreamingSkipMips=1

        \(comment("-------- Post-processing --------"))\
        r_Sharpening=0.5
        r_ChromaticAberration=0
        r_HDRGrainAmount=0.0
        r_DepthOfField=0
        r_MotionBlur=0
        r_Reflections=0
        r_SSReflections=0
        r_DepthOfFieldBokehQuality=1
        r_HDRBloom=0
        r_HDRVignetting=0

        \(comment("-------- LOD & View Distance --------"))\
        e_ViewDistRatio=180
        e_ViewDistRatioVegetation=180
        e_LodRatio=6
        e_ObjQuality=\(objectQuality)
        e_LodFaceAreaTargetSize=0.0015

        \(comment("-------- Shadows --------"))\
        e_ShadowsMaxTexRes=\(shadowTexRes)
        e_ShadowsPoolSize=\(shadowPoolSize)

        \(comment("-------- Water --------"))\
        e_WaterTessellationAmount=8

        \(comment("-------- Rain / Weather --------"))\
        r_Rain=1
        r_RainAmount=0.7
        r_RainDistMultiplier=1.0
        r_RainMaxViewDist=22
        r_RainMaxViewDist_Deferred=60
        r_RainIgnoreNearest=1
        wh_env_RainCurrentAmount=0.6
        wh_env_RainThreshold=0.3
        wh_env_RainWindStrength=15
        wh_env_PuddleCreationSpeed=0.009
        wh_env_PuddleDryupSpeed=0.001

        \(comment("-------- Other --------"))\
        wh_ui_ApseUnloadMode=1
        i_mouse_smooth=0

        \(comment("-------- Graphics Details --------"))\
        sys_spec_characters=\(globalQuality)
        sys_spec_globalillumination=\(globalQuality)
        sys_spec_light=\(globalQuality)
        sys_spec_objectdetail=\(objectQuality)
        sys_spec_particles=\(globalQuality)
        sys_spec_postprocessing=\(postProcessingQuality)
        sys_spec_quality=\(globalQuality)
        sys_spec_shading=\(globalQuality)
        sys_spec_shadows=\(shadowQuality)
        sys_spec_texture=\(globalQuality)
        """
    }

    private func writeExportFile(url: URL, content: String) throws {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
