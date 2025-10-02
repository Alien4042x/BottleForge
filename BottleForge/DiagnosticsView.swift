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
    @State private var showSuccessMetalFX = false
    @State private var successMessage = ""

    
    private let vcppFix = DiagnosticFix(
        id: "vcpp_universal_fix",
        title: "Fix Visual C++ 2015–2022 Runtime",
        description: "Applies override for unified Visual C++ Redistributable (32-bit and 64-bit) runtime libraries.\nUse this fix only if your app or game keeps prompting to install Visual C++ Redistributables.",
        dllOverrides: [
            "msvcp140", "msvcp140_1", "msvcp140_2",
            "vcruntime140", "vcruntime140_1",
            "concrt140", "vcomp140"
        ].map { WineTweakFile(dll: $0, mode: "native,builtin") }
    )

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

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vcppFix.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(vcppFix.description)
                        .font(.system(size: 14))
                    Text("(Both versions may be required by some apps.)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("🛠️ Run Fix") {
                    applyDiagnosticFix(vcppFix)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.18, green: 0.20, blue: 0.24)))
            .alert("✅ Fix Applied", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The diagnostic fix \"\(vcppFix.title)\" was successfully applied.")
            }

            // MetalFX toggle section
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Activate MetalFX")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Writes NVIDIA registry keys into the selected bottle (HKLM). Use Enable to set required values, or Delete to remove them.")
                        .font(.system(size: 14))
                    Text("To enable MetalFX: download GPTK from Apple, rename nvngx-on-metalfx.dll to nvngx.dll, and place it together with nvapi64.dll into the bottle's system32 folder.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Enable") { applyMetalFX(enable: true) }
                    .buttonStyle(.borderedProminent)
                Button("Delete") { deleteMetalFXKeys() }
                    .foregroundColor(.red)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.18, green: 0.20, blue: 0.24)))
            .alert("Done", isPresented: $showSuccessMetalFX) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage)
            }
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    
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

    // MARK: - MetalFX registry toggle
    func applyMetalFX(enable: Bool) {
        guard let bottle = appState.selectedBottle else {
            errorMessage = "❌ No bottle selected."
            showError = true
            return
        }

        let dword = enable ? "dword:00000001" : "dword:00000000"
        let fullPath = enable ? "C\\\\Windows\\\\System32" : ""

        var reg = "Windows Registry Editor Version 5.00\n\n"
        reg += "[HKEY_LOCAL_MACHINE\\SOFTWARE\\NVIDIA Corporation\\Global]\n"
        reg += "\"{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}\"=\(dword)\n\n"
        reg += "[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\nvlddmkm]\n"
        reg += "\"{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}\"=\(dword)\n\n"
        reg += "[HKEY_LOCAL_MACHINE\\SOFTWARE\\NVIDIA Corporation\\Global\\NGXCore]\n"
        reg += "\"FullPath\"=\"\(fullPath)\"\n"

        TweakExecutor.importRegistry(content: reg, to: bottle, using: settings, onError: { err in
            errorMessage = err
            showError = true
        }, onFinish: {
            successMessage = enable ? "✅ MetalFX has been enabled for this bottle." : "✅ MetalFX has been disabled for this bottle."
            showSuccessMetalFX = true
        })
    }

    // MARK: - Hard delete MetalFX values via .reg minus syntax
    func deleteMetalFXKeys() {
        guard let bottle = appState.selectedBottle else {
            errorMessage = "❌ No bottle selected."
            showError = true
            return
        }

        var reg = "Windows Registry Editor Version 5.00\n\n"
        reg += "[HKEY_LOCAL_MACHINE\\SOFTWARE\\NVIDIA Corporation\\Global]\n"
        reg += "\"{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}\"=-\n\n"
        reg += "[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\nvlddmkm]\n"
        reg += "\"{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}\"=-\n\n"
        reg += "[HKEY_LOCAL_MACHINE\\SOFTWARE\\NVIDIA Corporation\\Global\\NGXCore]\n"
        reg += "\"FullPath\"=-\n"

        TweakExecutor.importRegistry(content: reg, to: bottle, using: settings, onError: { err in
            errorMessage = err
            showError = true
        }, onFinish: {
            successMessage = "✅ MetalFX keys were deleted from this bottle."
            showSuccessMetalFX = true
        })
    }
}

 
struct DiagnosticFix: Identifiable {
    let id: String
    let title: String
    let description: String
    let dllOverrides: [WineTweakFile]
}

 
extension WineTweakFile {
    init(dll: String, mode: String) {
        self.name = nil
        self.source_url = nil
        self.destination = nil
        self.dll = dll
        self.mode = mode
    }
}
