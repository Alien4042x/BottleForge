//
//  DiagnosticsView.swift
//  BottleForge
//
//  Created by Radim Veselý on 28.03.2025.
//
//  Copyright (c) 2025 Radim Veselý
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//


import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject var appState: AppState
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    // 🔧 List of available diagnostic fixes
    private let diagnosticFixes: [DiagnosticFix] = [
        DiagnosticFix(
            id: "vcpp_universal_fix",
            title: "Fix Visual C++ 2015–2022 Runtime",
            description: "Applies override for unified Visual C++ Redistributable (32-bit and 64-bit) runtime libraries.\nUse this fix only if your app or game keeps prompting to install Visual C++ Redistributables.\n(Both versions may be required by some apps.)",
            dllOverrides: [
                "msvcp140", "msvcp140_1", "msvcp140_2",
                "vcruntime140", "vcruntime140_1",
                "concrt140", "vcomp140"
            ].map { WineTweakFile(dll: $0, mode: "native,builtin") }
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🩺 Diagnostics")
                .font(.title)
            Text("Diagnostic tools for fixing missing DLLs or misconfigurations.")
                .font(.system(size: 14))

            Divider()

            Text("ℹ️ This fix overrides Visual C++ runtime libraries from versions 2015 to 2022. Use only if your app or game keeps asking to install them.")
                .font(.system(size: 14))
                .padding(.bottom, 4)

            ForEach(diagnosticFixes) { fix in
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(fix.title)
                            .font(.system(size: 16, weight: .semibold))
                        Text(fix.description)
                            .font(.system(size: 14))
                    }

                    Spacer()

                    Button("🛠️ Run Fix") {
                        applyDiagnosticFix(fix)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.10)))
            }
            .alert("✅ Fix Applied", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The diagnostic fix \"\(diagnosticFixes.first?.title ?? "")\" was successfully applied.")
            }
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // Shared handler to apply the fix
    func applyDiagnosticFix(_ fix: DiagnosticFix) {
        guard let bottle = appState.selectedBottle else {
            errorMessage = "❌ No bottle selected."
            showError = true
            return
        }

        #if DEBUG
        print("🧪 Sending diagnostic tweak: \(fix.title)")
        #endif
        #if DEBUG
        print("🧾 DLL overrides:")
        for dll in fix.dllOverrides {
            print("   → DLL: \(dll.dll ?? "nil") = \(dll.mode ?? "nil")")
        }
        #endif

        let tweak = WineTweak(
            id: fix.id,
            title: fix.title,
            description: fix.description,
            description_long: nil,
            category: "Diagnostics",
            company: "Microsoft",
            platforms: ["windows"],
            conflicts_with: nil,
            steps: ["Set native override"],
            files: fix.dllOverrides,
            version: "1.0",
            date: "2025-04-12",
            installed: false
        )

        TweakExecutor.apply(tweak, to: bottle, using: settings, onError: { err in
            errorMessage = err
            showError = true
        }, onFinish: {
            showSuccess = true
            #if DEBUG
            print("✅ Diagnostic fix \(tweak.title) applied successfully")
            #endif
        })
    }
}

// Struct for universal fix
struct DiagnosticFix: Identifiable {
    let id: String
    let title: String
    let description: String
    let dllOverrides: [WineTweakFile]
}

// Extension for convenient DLL override creation without URL
extension WineTweakFile {
    init(dll: String, mode: String) {
        self.name = nil
        self.source_url = nil
        self.destination = nil
        self.dll = dll
        self.mode = mode
    }
}
