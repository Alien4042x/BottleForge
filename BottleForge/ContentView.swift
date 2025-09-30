//
//  ContentView.swift
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
import Foundation

class AppState: ObservableObject {
    @Published var selectedSection: Section = .diagnostics
    @Published var selectedBottle: Bottle?
    @Published var bottles: [Bottle] = []

    init() {
        loadBottles()
    }

    func loadBottles() {
        bottles.removeAll()

        let crossoverPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CrossOver/Bottles")
        let cxpatcherPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("CXPBottles")

        let pathsToCheck = [
            ("CrossOver", crossoverPath),
            ("CXPatcher", cxpatcherPath)
        ]

        for (label, basePath) in pathsToCheck {
            #if DEBUG
            print("🔍 Checking \(label) at: \(basePath.path)")
            #endif
            if FileManager.default.fileExists(atPath: basePath.path) {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: basePath, includingPropertiesForKeys: nil)
                    let folders = contents.filter { $0.hasDirectoryPath }
                    #if DEBUG
                    print("✅ Found \(folders.count) folders in \(label)")
                    #endif

                    for folder in folders {
                        let bottle = Bottle(name: folder.lastPathComponent, path: folder)
                        bottles.append(bottle)
                    }
                } catch {
                    #if DEBUG
                    print("❌ Error reading \(label): \(error)")
                    #endif
                }
            } else {
                #if DEBUG
                print("🚫 \(label) folder not found")
                #endif
            }
        }

        DispatchQueue.main.async {
            if let first = self.bottles.first {
                self.selectedBottle = first
                #if DEBUG
                print("✅ Auto-selected bottle: \(first.name)")
                #endif
            } else {
                #if DEBUG
                print("⚠️ No bottles found")
                #endif
            }
        }
    }


    func addCustomBottle(from url: URL) {
        let name = url.lastPathComponent
        let bottle = Bottle(name: name, path: url)
        bottles.append(bottle)
        selectedBottle = bottle
    }
}

 
enum Section: String, CaseIterable, Identifiable {
    case diagnostics = "Diagnostics"
    case files = "File Explorer"
    case wine_tricks = "WineTricks macOS"
    case bottleconfig = "Bottle Config"
    case settings = "Settings"
    case dependencies = "Dependencies"
    
    var id: String { rawValue }
}

 
struct ContentView: View {
    @ObservedObject var state: AppState
    @EnvironmentObject var settings: SettingsManager
    @State private var runtimeSelection: SettingsManager.WineRuntime = .crossover
    
    var body: some View {
        ZStack {
            
            HStack(spacing: 0) {
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Section.allCases, id: \.self) { section in
                        HStack {
                            Text(section.rawValue)
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            state.selectedSection == section ?
                                Color.black.opacity(0.1) :
                                Color.clear
                        )
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.selectedSection = section
                        }
                    }

                    Spacer()
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)
                .frame(minWidth: 220, maxWidth: 220)

                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("BottleForge")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding()

                    HStack(alignment: .center, spacing: 8) {
                        Text("Bottle:")
                        Picker("Bottle", selection: $state.selectedBottle) {
                            Text("None").tag(Optional<Bottle>.none)
                            ForEach(state.bottles, id: \.self) { bottle in
                                Text(bottle.name).tag(Optional(bottle))
                            }
                        }
                        .labelsHidden()

                        Button("Add Custom Path") {
                            openFolderDialog()
                        }

                        Text("Wine Runtime:")
                        Picker("Wine Runtime", selection: $runtimeSelection) {
                            if settings.crossoverAppPath != nil {
                                Text("CrossOver").tag(SettingsManager.WineRuntime.crossover)
                            }
                            if settings.cxpatcherAppPath != nil {
                                Text("CXPatcher").tag(SettingsManager.WineRuntime.cxpatcher)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .labelsHidden()
                        .task(id: runtimeSelection) {
                            if settings.selectedRuntime != runtimeSelection {
                                settings.selectedRuntime = runtimeSelection
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    sectionView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
            .ignoresSafeArea()
        }
        // Keep local selection in sync when runtime changes elsewhere
        .task(id: settings.selectedRuntime) {
            runtimeSelection = settings.selectedRuntime
        }
        .onAppear {
            runtimeSelection = settings.selectedRuntime
        }
    }

        

    
    @ViewBuilder
    private func sectionView() -> some View {
        switch state.selectedSection {
        case .diagnostics:
            DiagnosticsView(appState: state)
                .id(state.selectedBottle?.path)
        case .files:
            FilesView(appState: state)
                .id(state.selectedBottle?.path)
        case .wine_tricks:
            WineTricksView(appState: state)
                .id(state.selectedBottle?.path)
        case .bottleconfig:
            BottleConfigView(appState: state)
                .id(state.selectedBottle?.path)
        case .dependencies:
            DependenciesView()
        case .settings:
            SettingsView()
        }
    }

    private func openFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Bottle Folder"

        if panel.runModal() == .OK, let url = panel.url {
            state.addCustomBottle(from: url)
        }
    }
}

 

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State

    init(material: NSVisualEffectView.Material = .hudWindow,
         blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
         state: NSVisualEffectView.State = .active) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

#Preview {
    ContentView(state: AppState())
}
