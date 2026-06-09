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
import AppKit

struct SectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(.title)
        } icon: {
            SafeSystemImage(systemName: systemImage, fallbackSystemName: "square.grid.2x2")
                .font(.title2)
        }
    }
}

struct SafeSystemImage: View {
    let systemName: String
    let fallbackSystemName: String

    var body: some View {
        Image(systemName: resolvedSystemName)
    }

    private var resolvedSystemName: String {
        NSImage(systemSymbolName: systemName, accessibilityDescription: nil) != nil ? systemName : fallbackSystemName
    }
}

private enum AppTheme {
    static let windowBackground = Color(red: 0.085, green: 0.10, blue: 0.12)
    static let sidebarBackground = Color(red: 0.070, green: 0.078, blue: 0.095)
    static let sidebarBorder = Color.white.opacity(0.055)
    static let selectedItem = Color(red: 0.18, green: 0.215, blue: 0.255)
    static let hoveredItem = Color.white.opacity(0.055)
    static let statusPanel = Color.white.opacity(0.045)
    static let statusBorder = Color.white.opacity(0.06)
    static let accent = Color(red: 0.95, green: 0.42, blue: 0.18)
}

private struct AppIconView: View {
    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
    }
}

class AppState: ObservableObject {
    @Published var selectedSection: Section = .diagnostics
    @Published var selectedBottle: Bottle?
    @Published var bottles: [Bottle] = []

    init() {
        loadBottles()
    }

    func loadBottles() {
        let loadedBottles = BottleRepository.loadBottles()

        DispatchQueue.main.async {
            self.bottles = loadedBottles
            if let current = self.selectedBottle,
               loadedBottles.contains(where: { $0.path == current.path }) {
                return
            }

            if let first = loadedBottles.first {
                self.selectedBottle = first
                #if DEBUG
                print("✅ Auto-selected bottle: \(first.name)")
                #endif
            } else {
                self.selectedBottle = nil
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
    case wine_tricks = "Winetricks macOS"
    case game_config = "Game Config"
    case bottleconfig = "Bottle Config"
    case settings = "Settings"
    case dependencies = "Dependencies"
    
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .diagnostics:
            return "cross.case"
        case .files:
            return "folder"
        case .wine_tricks:
            return "wrench.and.screwdriver"
        case .game_config:
            return "gamecontroller"
        case .bottleconfig:
            return "slider.horizontal.3"
        case .settings:
            return "gearshape"
        case .dependencies:
            return "shippingbox"
        }
    }
}

 
struct ContentView: View {
    @ObservedObject var state: AppState
    @EnvironmentObject var settings: SettingsManager
    @State private var runtimeSelection: SettingsManager.WineRuntime = .crossover
    @State private var hoveredSection: Section? = nil
    
    var body: some View {
        ZStack {
            
            HStack(spacing: 0) {
                
                sidebar

                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label {
                            Text(state.selectedSection.rawValue)
                                .font(.system(size: 18, weight: .semibold))
                        } icon: {
                            SafeSystemImage(systemName: state.selectedSection.systemImage, fallbackSystemName: "square.grid.2x2")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
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
            .background(AppTheme.windowBackground)
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

        

    private var sidebar: some View {
        ZStack {
            AppTheme.sidebarBackground
                .overlay(
                    Rectangle()
                        .fill(AppTheme.sidebarBorder)
                        .frame(width: 1),
                    alignment: .trailing
                )

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    AppIconView()
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("BottleForge")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .padding(.top, 48)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Section.allCases, id: \.self) { section in
                        SidebarItem(
                            section: section,
                            isSelected: state.selectedSection == section,
                            isHovered: hoveredSection == section
                        )
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            hoveredSection = hovering ? section : (hoveredSection == section ? nil : hoveredSection)
                        }
                        .onTapGesture {
                            state.selectedSection = section
                        }
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        SafeSystemImage(systemName: "folder", fallbackSystemName: "doc")
                        Text(state.selectedBottle?.name ?? "No bottle selected")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.system(size: 12, weight: .medium))

                    HStack(spacing: 6) {
                        SafeSystemImage(systemName: "cpu", fallbackSystemName: "gearshape")
                        Text(settings.selectedRuntime.displayName)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.statusPanel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.statusBorder, lineWidth: 1)
                        )
                )
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 14)
        }
        .frame(minWidth: 232, maxWidth: 232)
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
        case .game_config:
            GameConfigView(appState: state)
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

private struct SidebarItem: View {
    let section: Section
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            SafeSystemImage(systemName: section.systemImage, fallbackSystemName: "square.grid.2x2")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 20)
                .foregroundColor(isSelected ? .white : .secondary)

            Text(section.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer()

            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.accent.opacity(0.90))
                    .frame(width: 3, height: 18)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
    }

    private var backgroundColor: Color {
        if isSelected {
            return AppTheme.selectedItem
        }
        if isHovered {
            return AppTheme.hoveredItem
        }
        return Color.clear
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
