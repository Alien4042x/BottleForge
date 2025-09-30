//
//  BottleConfig.swift
//  BottleForge
//
//  Created by Radim Veselý on 23.09.2025.
//

import SwiftUI

// MARK: - BottleConfigView

struct BottleConfigView: View {
    @ObservedObject var appState: AppState
    @EnvironmentObject var settings: SettingsManager

    @State private var toggles: [EnvToggle] = []
    @State private var editingId: UUID? = nil
    @State private var isDirty = false
    @State private var loadingError: String?
    @State private var infoMessage: String?
    @State private var existingBoolKeys: Set<String> = []
    private let nonEditableKeys: Set<String> = [
        "D3DM_ENABLE_METALFX",
        "ROSETTA_ADVERTISE_AVX",
        "MTL_HUD_ENABLED"
    ]

    private let defaultKeys: [String] = [
        "WINEESYNC",
        "WINEMSYNC",
        "D3DM_ENABLE_METALFX",
        "ROSETTA_ADVERTISE_AVX",
        "MTL_HUD_ENABLED"
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
        let defaultOn: Bool
    }

    private let tips: [TipItem] = [
        TipItem(
            key: "D3DM_ENABLE_METALFX",
            description: "MetalFX upscaling (similar to DLSS/FSR). Increases FPS by rendering at lower resolution and upscaling on GPU. Not all games support it and requires that MetalFX is installed on your system.\nTo enable MetalFX: download GPTK from Apple, rename nvngx-on-metalfx.dll to nvngx.dll, and place it together with nvapi64.dll into the bottle's system32 folder.",
            defaultOn: true
        ),
        TipItem(
            key: "ROSETTA_ADVERTISE_AVX",
            description: "Forces Rosetta 2 to report AVX support. Some x86 games may start only with this enabled, but it can cause crashes or glitches.",
            defaultOn: false
        ),
        TipItem(
            key: "MTL_HUD_ENABLED",
            description: "Metal HUD – GPU-only overlay with FPS and basic GPU metrics.",
            defaultOn: false
        )
    ]

    private func addTip(_ tip: TipItem) {
        // Do not duplicate if already present in file; if toggle exists, just set default state
        if let idx = toggles.firstIndex(where: { $0.key == tip.key }) {
            toggles[idx].isOn = tip.defaultOn
            if !nonEditableKeys.contains(tip.key) {
                editingId = toggles[idx].id
            }
        } else {
            let new = EnvToggle(key: tip.key, isOn: tip.defaultOn, isBoolean: true)
            toggles.append(new)
            if !nonEditableKeys.contains(tip.key) {
                editingId = new.id
            }
        }
        existingBoolKeys.insert(tip.key)
        isDirty = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔧 Bottle Config")
                .font(.title)
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
                        let new = EnvToggle(key: "NEW_VARIABLE", isOn: false, isBoolean: true)
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
                                    Text(tip.description)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .layoutPriority(1)
                                }
                                Spacer()
                                if !existingBoolKeys.contains(tip.key) {
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

            // Track which boolean-like keys are already present in file
            var present: Set<String> = []
            for (k, v) in envMap {
                if skipKeys.contains(k) { continue }
                let lowered = v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isBoolLike = ["0","1","true","false","yes","no","on","off"].contains(lowered)
                if isBoolLike { present.insert(k) }
            }
            existingBoolKeys = present

            // Seed with defaults + what exists in file
            var keys = Set(defaultKeys)
            keys.formUnion(envMap.keys)
            var newToggles: [EnvToggle] = []
            for k in keys.sorted() {
                if skipKeys.contains(k) { continue }
                let raw = envMap[k] ?? "0"
                let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isBoolLike = ["0","1","true","false","yes","no","on","off"].contains(lowered)
                if !isBoolLike && envMap[k] != nil {
                    // Non-boolean string present in file – preserve it but do not show in toggles
                    continue
                }
                let on = normalizeBool(raw)
                newToggles.append(EnvToggle(key: k, isOn: on, isBoolean: true))
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
            existingBoolKeys = Set(toggles.map { $0.key })
            isDirty = false
            infoMessage = "Saved: \(url.path)"
        } catch {
            loadingError = error.localizedDescription
        }
    }

    private func togglesDict() -> [String: String] {
        var dict: [String: String] = [:]
        for t in toggles where t.isBoolean {
            dict[t.key] = t.isOn ? "1" : "0"
        }
        return dict
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
            // Keys we control via toggles: either known defaults or previously detected as boolean-like
            // Never treat skipKeys as managed for deletion
            return (existingBoolKeys.contains(key) || defaultKeys.contains(key)) && !skipKeys.contains(key)
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
}

struct ToggleListView: View {
    @Binding var toggles: [EnvToggle]
    @Binding var editingId: UUID?
    let nonEditableKeys: Set<String>
    var onChange: () -> Void
    @FocusState private var focusedId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(toggles.indices, id: \.self) { idx in
                let binding = $toggles[idx]
                let t = toggles[idx]
                HStack(alignment: .center, spacing: 12) {
                    Toggle(isOn: binding.isOn) {
                        Group {
                            if editingId == t.id {
                                TextField("ENV_VAR", text: binding.key)
                                    .font(.system(size: 13))
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedId, equals: t.id)
                                    .onSubmit {
                                        editingId = nil
                                        onChange()
                                    }
                            } else {
                                Text(t.key)
                                    .font(.system(size: 13))
                                    .onTapGesture(count: 2) {
                                        guard !nonEditableKeys.contains(t.key) else { return }
                                        editingId = t.id
                                        focusedId = t.id
                                    }
                            }
                        }
                    }
                    .toggleStyle(CheckboxToggleStyle())

                    Spacer()

                    Button(role: .destructive) {
                        toggles.remove(at: idx)
                        onChange()
                    } label: {
                        Text("Remove")
                    }
                }
                .onChange(of: toggles[idx].isOn) { _ in onChange() }
                .onChange(of: toggles[idx].key) { _ in onChange() }
                Divider()
            }
        }
        .onChange(of: editingId) { new in
            focusedId = new
        }
    }
}
