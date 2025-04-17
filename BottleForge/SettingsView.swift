//
//  SettingsView.swift
//  BottleForge
//
//  Created by Radim Veselý on 11.04.2025.
//
//  Copyright (c) 2025 Radim Veselý
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @AppStorage("maxFilesEnabled") private var maxFilesEnabled: Bool = false


    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("⚙️ Settings")
                .font(.title)

            Text("Configuration tools for setting up launchers like CrossOver or CXPatcher.")
                .font(.system(size: 14))

            Divider()
           
            SwiftUI.Section(header: Text("Applications")) {
                HStack {
                    Text("CrossOver.app:")
                    Spacer()
                    Text(settings.crossoverAppPath?.lastPathComponent ?? "Not set")
                    Button("Select") {
                        selectApplication { url in
                            if let url = url {
                                settings.crossoverAppPath = url
                                settings.cxpatcherAppPath = settings.cxpatcherAppPath
                                settings.save()
                            }
                        }
                    }
                    Button("Remove") {
                        settings.clearCrossoverAppPath()
                    }
                    .foregroundColor(.red)
                }

                HStack {
                    Text("CXPatcher.app:")
                    Spacer()
                    Text(settings.cxpatcherAppPath?.lastPathComponent ?? "Not set")
                    Button("Select") {
                        selectApplication { url in
                            if let url = url {
                                settings.cxpatcherAppPath = url
                                settings.save()
                            }
                        }
                    }
                    Button("Remove") {
                        settings.clearCxpatcherAppPath()
                    }
                    .foregroundColor(.red)
                }
            }

            SwiftUI.Section(header: Text("Validation")) {
                HStack{
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        if settings.isValid {
                            Text("✅ App path is set.")
                                .foregroundColor(.green)
                        } else {
                            Text("⚠️ Please set at least one app path.")
                                .foregroundColor(.red)
                        }

                        if settings.hasExecutables {
                            Text("✅ Wine & Regedit found.")
                                .foregroundColor(.green)
                        } else {
                            Text("⚠️ Executables missing in available app.")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding()
    }

    func selectApplication(onSelect: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.title = "Select Application (.app)"

        if panel.runModal() == .OK {
            onSelect(panel.url)
        } else {
            onSelect(nil)
        }
    }
}
